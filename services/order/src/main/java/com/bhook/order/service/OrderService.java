package com.bhook.order.service;

import com.bhook.order.api.dto.CreateOrderRequest;
import com.bhook.order.api.dto.OrderResponse;
import com.bhook.order.api.dto.QuoteResponse;
import com.bhook.order.client.CatalogClient;
import com.bhook.order.client.CatalogView;
import com.bhook.order.client.CampusClient;
import com.bhook.order.client.CustomerProfileView;
import com.bhook.order.domain.Cart;
import com.bhook.order.domain.CartItem;
import com.bhook.order.domain.IdempotencyKey;
import com.bhook.order.domain.OrderEntity;
import com.bhook.order.domain.OrderItemSnapshot;
import com.bhook.order.domain.OrderStatus;
import com.bhook.order.domain.FulfillmentMode;
import com.bhook.order.domain.OrderStatusHistory;
import com.bhook.order.domain.PaymentState;
import com.bhook.order.outbox.OutboxWriter;
import com.bhook.order.repository.CartItemRepository;
import com.bhook.order.repository.CartRepository;
import com.bhook.order.repository.IdempotencyKeyRepository;
import com.bhook.order.repository.OrderItemRepository;
import com.bhook.order.repository.OrderRepository;
import com.bhook.order.repository.OrderStatusHistoryRepository;
import com.bhook.common.error.BhookException;
import com.bhook.common.events.OrderCreatedEvent;
import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final OrderStatusHistoryRepository statusHistoryRepository;
    private final IdempotencyKeyRepository idempotencyRepository;
    private final CatalogClient catalogClient;
    private final CartService cartService;
    private final OrderContextResolver contextResolver;
    private final OutboxWriter outbox;
    private final ObjectMapper objectMapper;
    private final CampusClient campusClient;

    @Value("${bhook.orders.cancel-window.paid-seconds:120}") private long cancelWindowPaidSeconds;
    @Value("${bhook.orders.cancel-window.accepted-seconds:60}") private long cancelWindowAcceptedSeconds;

    @Transactional(readOnly = true)
    public QuoteResponse quote(String bearer, UUID vendorId, Integer cartVersion) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        CatalogClient.VendorView vendor = contextResolver.requireOrderableVendor(vendorId, me.activeCampusId(), bearer);
        Cart cart = cartRepository.findByUserIdAndVendorId(me.userId(), vendorId)
                .orElseThrow(() -> BhookException.notFound("Cart not found"));
        if (cartVersion != null && !Objects.equals(cartVersion, cart.getVersion())) {
            throw BhookException.conflict("Cart version mismatch");
        }
        List<CartItem> lines = cartItemRepository.findByCartIdOrderByCreatedAtAsc(cart.getId());
        if (lines.isEmpty()) throw BhookException.validation("Cart is empty");

        CatalogView catalog = catalogClient.getCatalog(vendorId, bearer);
        Map<UUID, CatalogView.ItemView> byId = contextResolver.indexItems(catalog);
        PricingResult pricing = price(lines, byId);

        long platformFeeMinor = campusClient.platformFeeMinor(vendor.campusId);
        return new QuoteResponse(
                vendorId, vendor.campusId, "INR",
                pricing.subtotalMinor, pricing.taxMinor,
                0L, platformFeeMinor, 0L,
                pricing.subtotalMinor + pricing.taxMinor + platformFeeMinor,
                cart.getVersion() == null ? 0 : cart.getVersion(),
                pricing.lines.stream().map(l -> new QuoteResponse.QuotedLine(
                        UUID.randomUUID(), l.itemId, l.itemName, l.variantId, l.variantName,
                        l.quantity, l.unitPriceMinor, l.taxMinor, l.lineTotalMinor
                )).toList()
        );
    }

    @Transactional
    public OrderResponse create(String bearer, String idempotencyKey, CreateOrderRequest req) {
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            Optional<IdempotencyKey> existing = idempotencyRepository.findById(idempotencyKey);
            if (existing.isPresent()) {
                return toResponse(orderRepository.findById(existing.get().getOrderId())
                        .orElseThrow(() -> BhookException.notFound("Order not found")));
            }
        }

        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        CatalogClient.VendorView vendor = contextResolver.requireOrderableVendor(req.vendorId(), me.activeCampusId(), bearer);
        Cart cart = cartRepository.findByUserIdAndVendorId(me.userId(), req.vendorId())
                .orElseThrow(() -> BhookException.notFound("Cart not found"));
        if (req.cartVersion() != null && !Objects.equals(req.cartVersion(), cart.getVersion())) {
            throw BhookException.conflict("Cart version mismatch");
        }
        List<CartItem> lines = cartItemRepository.findByCartIdOrderByCreatedAtAsc(cart.getId());
        if (lines.isEmpty()) throw BhookException.validation("Cart is empty");

        CatalogView catalog = catalogClient.getCatalog(req.vendorId(), bearer);
        Map<UUID, CatalogView.ItemView> byId = contextResolver.indexItems(catalog);
        PricingResult pricing = price(lines, byId);
        long platformFeeMinor = campusClient.platformFeeMinor(vendor.campusId);
        long total = pricing.subtotalMinor + pricing.taxMinor + platformFeeMinor;

        OrderEntity order = orderRepository.save(OrderEntity.builder()
                .orderNumber(generateOrderNumber())
                .userId(me.userId())
                .campusId(me.activeCampusId())
                .vendorId(req.vendorId())
                .pickupLocationId(req.pickupLocationId())
                .fulfillmentMode(req.fulfillmentMode() == null
                    ? FulfillmentMode.DELIVERY : req.fulfillmentMode())
                .status(OrderStatus.PAYMENT_PENDING)
                .paymentState(PaymentState.PENDING)
                .currency("INR")
                .subtotalMinor(pricing.subtotalMinor)
                .taxMinor(pricing.taxMinor)
                .deliveryFeeMinor(0L)
                .platformFeeMinor(platformFeeMinor)
                .discountMinor(0L)
                .totalMinor(total)
                .paymentMethod(req.paymentMethod())
                .clientReference(req.clientReference())
                .autoAccept(vendor.autoAcceptOrders)
                .expiresAt(Instant.now().plus(15, ChronoUnit.MINUTES))
                .build());

        for (PricingLine l : pricing.lines) {
            orderItemRepository.save(OrderItemSnapshot.builder()
                    .orderId(order.getId())
                    .itemId(l.itemId)
                    .itemName(l.itemName)
                    .variantId(l.variantId)
                    .variantName(l.variantName)
                    .modifiersSnapshot(l.modifiersJson)
                    .quantity(l.quantity)
                    .unitPriceMinor(l.unitPriceMinor)
                    .taxMinor(l.taxMinor)
                    .lineTotalMinor(l.lineTotalMinor)
                    .build());
        }
        statusHistoryRepository.save(OrderStatusHistory.builder()
                .orderId(order.getId())
                .fromStatus(null)
                .toStatus(OrderStatus.PAYMENT_PENDING)
                .actorType("SYSTEM")
                .actorId(me.userId())
                .reason("ORDER_CREATED")
                .build());

        cartItemRepository.deleteByCartId(cart.getId());
        cartRepository.delete(cart);

        outbox.write(Topics.ORDER_EVENTS, "Order", order.getId().toString(),
                OrderCreatedEvent.EVENT_TYPE,
                new OrderCreatedEvent(order.getId(), order.getOrderNumber(), me.userId(),
                        vendor.id, order.getCampusId(), order.getPickupLocationId(),
                        order.getCurrency(), order.getTotalMinor(), order.getPaymentMethod(), Instant.now(),
                        vendor.commissionPercent == null ? 1500 : (int) Math.round(vendor.commissionPercent * 100)));

        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            idempotencyRepository.save(IdempotencyKey.builder()
                    .key(idempotencyKey)
                    .userId(me.userId())
                    .orderId(order.getId())
                    .build());
        }

        return toResponse(order);
    }

    @Transactional(readOnly = true)
    public OrderResponse get(UUID userId, UUID orderId) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> BhookException.notFound("Order not found"));
        if (!order.getUserId().equals(userId)) {
            throw BhookException.forbidden("Order does not belong to this user");
        }
        return toResponse(order);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> listForUser(UUID userId) {
        return orderRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toResponseNoLines).toList();
    }

    @Transactional
    public OrderResponse cancel(UUID userId, UUID orderId, String reason) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> BhookException.notFound("Order not found"));
        if (!order.getUserId().equals(userId)) {
            throw BhookException.forbidden("Order does not belong to this user");
        }
        if (!canCustomerCancel(order)) {
            throw new BhookException(com.bhook.common.error.ErrorCode.ORDER_NOT_MODIFIABLE,
                    org.springframework.http.HttpStatus.CONFLICT,
                    "Order can no longer be cancelled by the customer");
        }
        return transition(order, OrderStatus.CANCELLED, "CUSTOMER", userId,
                reason == null || reason.isBlank() ? "CUSTOMER_CANCELLED" : reason);
    }

    @Transactional
    public OrderResponse transition(OrderEntity order, OrderStatus to, String actorType, UUID actorId, String reason) {
        OrderStatus from = order.getStatus();
        order.setStatus(to);
        if (to == OrderStatus.PAID) order.setPaymentState(PaymentState.PAID);
        if (to == OrderStatus.CANCELLED || to == OrderStatus.PAYMENT_FAILED) order.setPaymentState(PaymentState.FAILED);
        if (to == OrderStatus.REFUNDED) order.setPaymentState(PaymentState.REFUNDED);
        orderRepository.save(order);
        statusHistoryRepository.save(OrderStatusHistory.builder()
                .orderId(order.getId())
                .fromStatus(from)
                .toStatus(to)
                .actorType(actorType)
                .actorId(actorId)
                .reason(reason)
                .build());
        outbox.write(Topics.ORDER_EVENTS, "Order", order.getId().toString(),
                OrderStatusChangedEvent.EVENT_TYPE,
                new OrderStatusChangedEvent(order.getId(), order.getVendorId(), order.getUserId(),
                        order.getCampusId(), from == null ? null : from.name(), to.name(),
                        actorType, actorId, reason, Instant.now()));
        return toResponse(order);
    }

    private boolean canCustomerCancel(OrderEntity order) {
        long ageSeconds = java.time.Duration.between(order.getCreatedAt(), Instant.now()).getSeconds();
        return switch (order.getStatus()) {
            case PAYMENT_PENDING -> true;
            case PAID -> ageSeconds <= cancelWindowPaidSeconds;
            case VENDOR_ACCEPTED -> ageSeconds <= cancelWindowAcceptedSeconds;
            default -> false;
        };
    }

    private String generateOrderNumber() {
        String day = LocalDate.now(ZoneOffset.UTC).toString().replace("-", "");
        int suffix = ThreadLocalRandom.current().nextInt(100000, 999999);
        return "BH-" + day + "-" + suffix;
    }

    private PricingResult price(List<CartItem> lines, Map<UUID, CatalogView.ItemView> byId) {
        List<PricingLine> pricedLines = new ArrayList<>();
        long subtotal = 0L;
        long tax = 0L;
        for (CartItem l : lines) {
            CatalogView.ItemView item = byId.get(l.getItemId());
            if (item == null || !"ACTIVE".equals(item.status()) || !item.available()) {
                throw BhookException.notFound("Item not available");
            }
            long unit = cartService.computeUnitPriceMinor(item, l.getVariantId(), readUuidList(l.getModifierIds()));
            long lineTax = item.taxMinor() * l.getQuantity();
            long lineTotal = unit * l.getQuantity() + lineTax;
            String variantName = null;
            if (l.getVariantId() != null) {
                variantName = item.variants().stream()
                        .filter(v -> v.id().equals(l.getVariantId()))
                        .findFirst().map(CatalogView.VariantView::name).orElse(null);
            }
            pricedLines.add(new PricingLine(
                    l.getItemId(), item.name(), l.getVariantId(), variantName,
                    l.getModifierIds(), l.getQuantity(), unit, lineTax, lineTotal
            ));
            subtotal += unit * l.getQuantity();
            tax += lineTax;
        }
        return new PricingResult(subtotal, tax, pricedLines);
    }

    private OrderResponse toResponse(OrderEntity o) {
        List<OrderResponse.OrderLine> lines = orderItemRepository.findByOrderId(o.getId()).stream()
                .map(l -> new OrderResponse.OrderLine(
                        l.getId(), l.getItemId(), l.getItemName(),
                        l.getVariantId(), l.getVariantName(),
                        l.getQuantity(), l.getUnitPriceMinor(), l.getTaxMinor(), l.getLineTotalMinor()
                )).toList();
        return new OrderResponse(
                o.getId(), o.getOrderNumber(), o.getStatus(), o.getPaymentState(),
                o.getCampusId(), o.getVendorId(), o.getPickupLocationId(), o.getFulfillmentMode(), o.getCurrency(),
                o.getSubtotalMinor(), o.getTaxMinor(), o.getDeliveryFeeMinor(), o.getPlatformFeeMinor(),
                o.getDiscountMinor(), o.getTotalMinor(), o.getPaymentMethod(), o.getClientReference(),
                o.getVersion(), o.getExpiresAt(), o.getCreatedAt(), lines
        );
    }

    private OrderResponse toResponseNoLines(OrderEntity o) {
        return new OrderResponse(
                o.getId(), o.getOrderNumber(), o.getStatus(), o.getPaymentState(),
                o.getCampusId(), o.getVendorId(), o.getPickupLocationId(), o.getFulfillmentMode(), o.getCurrency(),
                o.getSubtotalMinor(), o.getTaxMinor(), o.getDeliveryFeeMinor(), o.getPlatformFeeMinor(),
                o.getDiscountMinor(), o.getTotalMinor(), o.getPaymentMethod(), o.getClientReference(),
                o.getVersion(), o.getExpiresAt(), o.getCreatedAt(), List.of()
        );
    }

    private List<UUID> readUuidList(String json) {
        try {
            if (json == null || json.isBlank()) return List.of();
            return objectMapper.readValue(json, objectMapper.getTypeFactory().constructCollectionType(List.class, UUID.class));
        } catch (Exception e) {
            return List.of();
        }
    }

    private record PricingResult(long subtotalMinor, long taxMinor, List<PricingLine> lines) {}

    private record PricingLine(
            UUID itemId, String itemName, UUID variantId, String variantName,
            String modifiersJson, int quantity, long unitPriceMinor, long taxMinor, long lineTotalMinor
    ) {}
}
