package com.bhook.order.service;

import com.bhook.order.api.dto.OrderResponse;
import com.bhook.order.api.dto.VendorAnalyticsResponse;
import com.bhook.order.domain.OrderEntity;
import com.bhook.order.domain.OrderItemSnapshot;
import com.bhook.order.domain.OrderStatus;
import com.bhook.order.repository.OrderItemRepository;
import com.bhook.order.repository.OrderRepository;
import com.bhook.common.error.BhookException;
import com.bhook.common.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class VendorOrderService {

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final OrderService orderService;

    private static final Set<OrderStatus> ACTIVE_QUEUE = Set.of(
            OrderStatus.PAID, OrderStatus.VENDOR_ACCEPTED, OrderStatus.PREPARING,
            OrderStatus.READY_FOR_PICKUP, OrderStatus.DELIVERY_ASSIGNED
    );

    private static final Set<OrderStatus> VENDOR_CANCELLABLE = Set.of(
            OrderStatus.PAID, OrderStatus.VENDOR_ACCEPTED, OrderStatus.PREPARING
    );

    private static final Set<OrderStatus> REVENUE_STATUSES = Set.of(
            OrderStatus.PAID, OrderStatus.VENDOR_ACCEPTED, OrderStatus.PREPARING,
            OrderStatus.READY_FOR_PICKUP, OrderStatus.DELIVERY_ASSIGNED, OrderStatus.PICKED_UP,
            OrderStatus.OUT_FOR_DELIVERY, OrderStatus.ARRIVED_AT_PICKUP_POINT,
            OrderStatus.READY_FOR_COLLECTION, OrderStatus.COLLECTED, OrderStatus.COMPLETED
    );

    @Transactional(readOnly = true)
    public List<OrderResponse> queue(UUID vendorId) {
        List<OrderEntity> orders = orderRepository.findByVendorIdAndStatusInOrderByCreatedAtDesc(vendorId, List.copyOf(ACTIVE_QUEUE));
        return toResponses(orders);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> history(UUID vendorId, Instant from, Instant to) {
        List<OrderEntity> orders = orderRepository
            .findByVendorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
                vendorId, from, to);
        return toResponses(orders);
    }

    private List<OrderResponse> toResponses(List<OrderEntity> orders) {
        if (orders.isEmpty()) return List.of();
        List<UUID> orderIds = orders.stream().map(OrderEntity::getId).toList();
        Map<UUID, List<OrderResponse.OrderLine>> linesByOrder = new LinkedHashMap<>();
        for (OrderItemSnapshot l : orderItemRepository.findByOrderIdIn(orderIds)) {
            linesByOrder.computeIfAbsent(l.getOrderId(), k -> new ArrayList<>())
                    .add(new OrderResponse.OrderLine(
                            l.getId(), l.getItemId(), l.getItemName(),
                            l.getVariantId(), l.getVariantName(),
                            l.getQuantity(), l.getUnitPriceMinor(), l.getTaxMinor(), l.getLineTotalMinor()));
        }
        return orders.stream()
                .map(o -> new OrderResponse(
                        o.getId(), o.getOrderNumber(), o.getStatus(), o.getPaymentState(),
                        o.getCampusId(), o.getVendorId(), o.getPickupLocationId(), o.getFulfillmentMode(), o.getCurrency(),
                        o.getSubtotalMinor(), o.getTaxMinor(), o.getDeliveryFeeMinor(), o.getPlatformFeeMinor(),
                        o.getDiscountMinor(), o.getTotalMinor(), o.getPaymentMethod(), o.getClientReference(),
                        o.getVersion(), o.getExpiresAt(), o.getCreatedAt(),
                        linesByOrder.getOrDefault(o.getId(), List.of())))
                .toList();
    }

    @Transactional(readOnly = true)
    public VendorAnalyticsResponse analytics(UUID vendorId, Instant from, Instant to) {
        List<OrderEntity> inRange = orderRepository.findByVendorIdOrderByCreatedAtDesc(vendorId).stream()
                .filter(o -> from == null || !o.getCreatedAt().isBefore(from))
                .filter(o -> to == null || o.getCreatedAt().isBefore(to))
                .toList();

        Map<String, Long> byStatus = new TreeMap<>();
        for (OrderEntity o : inRange) {
            byStatus.merge(o.getStatus().name(), 1L, Long::sum);
        }

        List<OrderEntity> counted = inRange.stream()
                .filter(o -> REVENUE_STATUSES.contains(o.getStatus()))
                .toList();

        long gross = counted.stream().mapToLong(OrderEntity::getTotalMinor).sum();
        long net = counted.stream().mapToLong(OrderEntity::getSubtotalMinor).sum();
        long totalOrders = counted.size();
        long avg = totalOrders == 0 ? 0 : Math.round((double) gross / totalOrders);
        String currency = counted.isEmpty() ? "INR" : counted.get(0).getCurrency();

        Map<String, long[]> dayMap = new TreeMap<>();
        for (OrderEntity o : counted) {
            String day = o.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate().toString();
            long[] agg = dayMap.computeIfAbsent(day, k -> new long[2]);
            agg[0] += 1;
            agg[1] += o.getTotalMinor();
        }
        List<VendorAnalyticsResponse.DailyPoint> daily = dayMap.entrySet().stream()
                .map(e -> new VendorAnalyticsResponse.DailyPoint(e.getKey(), e.getValue()[0], e.getValue()[1]))
                .toList();

        List<UUID> orderIds = counted.stream().map(OrderEntity::getId).toList();
        Map<UUID, ItemAgg> itemAggs = new LinkedHashMap<>();
        long itemsSold = 0;
        if (!orderIds.isEmpty()) {
            for (OrderItemSnapshot l : orderItemRepository.findByOrderIdIn(orderIds)) {
                ItemAgg agg = itemAggs.computeIfAbsent(l.getItemId(), k -> new ItemAgg(l.getItemName()));
                agg.quantity += l.getQuantity();
                agg.revenueMinor += l.getLineTotalMinor();
                agg.orders.add(l.getOrderId());
                if (agg.name == null || agg.name.isBlank()) agg.name = l.getItemName();
                itemsSold += l.getQuantity();
            }
        }
        List<VendorAnalyticsResponse.ItemStat> topItems = itemAggs.entrySet().stream()
                .map(e -> new VendorAnalyticsResponse.ItemStat(
                        e.getKey(), e.getValue().name, e.getValue().quantity,
                        e.getValue().revenueMinor, e.getValue().orders.size()))
                .sorted(Comparator.comparingLong(VendorAnalyticsResponse.ItemStat::quantity).reversed())
                .toList();

        return new VendorAnalyticsResponse(from, to, currency, totalOrders, gross, net, avg,
                itemsSold, byStatus, daily, topItems);
    }

    private static final class ItemAgg {
        private String name;
        private long quantity;
        private long revenueMinor;
        private final Set<UUID> orders = new java.util.HashSet<>();

        private ItemAgg(String name) {
            this.name = name;
        }
    }

    @Transactional
    public OrderResponse accept(UUID vendorId, UUID actorUserId, UUID orderId) {
        return vendorTransition(vendorId, actorUserId, orderId, OrderStatus.PAID, OrderStatus.VENDOR_ACCEPTED, "VENDOR_ACCEPTED");
    }

    @Transactional
    public OrderResponse reject(UUID vendorId, UUID actorUserId, UUID orderId, String reason) {
        return vendorTransition(vendorId, actorUserId, orderId, OrderStatus.PAID, OrderStatus.VENDOR_REJECTED,
                reason == null || reason.isBlank() ? "VENDOR_REJECTED" : reason);
    }

    @Transactional
    public OrderResponse cancelAfterAccept(UUID vendorId, UUID actorUserId, UUID orderId, String reason) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> BhookException.notFound("Order not found"));
        if (!order.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Order does not belong to this vendor");
        }
        if (!VENDOR_CANCELLABLE.contains(order.getStatus())) {
            throw new BhookException(ErrorCode.INVALID_STATE_TRANSITION, HttpStatus.CONFLICT,
                    "Vendor cannot cancel from " + order.getStatus());
        }
        return orderService.transition(order, OrderStatus.VENDOR_REJECTED, "VENDOR", actorUserId,
                reason == null || reason.isBlank() ? "VENDOR_CANCELLED_AFTER_ACCEPT" : reason);
    }

    @Transactional
    public OrderResponse markPreparing(UUID vendorId, UUID actorUserId, UUID orderId) {
        return vendorTransition(vendorId, actorUserId, orderId, OrderStatus.VENDOR_ACCEPTED, OrderStatus.PREPARING, "PREPARATION_STARTED");
    }

    @Transactional
    public OrderResponse markReady(UUID vendorId, UUID actorUserId, UUID orderId) {
        return vendorTransition(vendorId, actorUserId, orderId, OrderStatus.PREPARING, OrderStatus.READY_FOR_PICKUP, "READY_FOR_PICKUP");
    }

    private OrderResponse vendorTransition(UUID vendorId, UUID actorUserId, UUID orderId,
                                           OrderStatus expected, OrderStatus target, String reason) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> BhookException.notFound("Order not found"));
        if (!order.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Order does not belong to this vendor");
        }
        if (order.getStatus() != expected) {
            throw new BhookException(ErrorCode.INVALID_STATE_TRANSITION, HttpStatus.CONFLICT,
                    "Cannot transition from " + order.getStatus() + " to " + target);
        }
        return orderService.transition(order, target, "VENDOR", actorUserId, reason);
    }
}
