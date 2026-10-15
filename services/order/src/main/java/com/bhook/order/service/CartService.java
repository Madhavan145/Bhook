package com.bhook.order.service;

import com.bhook.order.api.dto.CartResponse;
import com.bhook.order.api.dto.PutCartItemRequest;
import com.bhook.order.client.CatalogClient;
import com.bhook.order.client.CatalogView;
import com.bhook.order.client.CustomerProfileView;
import com.bhook.order.domain.Cart;
import com.bhook.order.domain.CartItem;
import com.bhook.order.repository.CartItemRepository;
import com.bhook.order.repository.CartRepository;
import com.bhook.common.error.BhookException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CartService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final OrderContextResolver contextResolver;
    private final com.bhook.order.client.CatalogClient catalogClient;
    private final ObjectMapper objectMapper;

    @Transactional
    public CartResponse putItem(String bearer, PutCartItemRequest req) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        contextResolver.requireOrderableVendor(req.vendorId(), me.activeCampusId(), bearer);

        cartRepository.findByUserIdAndVendorId(me.userId(), req.vendorId()).ifPresent(existing -> {
            if (req.version() != null && !Objects.equals(req.version(), existing.getVersion())) {
                throw BhookException.conflict("Cart version mismatch — refresh cart and retry");
            }
        });

        if (cartRepository.findByUserId(me.userId()).stream()
            .anyMatch(cart -> !cart.getVendorId().equals(req.vendorId())
                && cartItemRepository.existsByCartId(cart.getId()))) {
            throw BhookException.conflict("You have an active cart for another vendor. Clear it first.");
        }

        CatalogView catalog = catalogClient.getCatalog(req.vendorId(), bearer);
        Map<UUID, CatalogView.ItemView> items = contextResolver.indexItems(catalog);
        CatalogView.ItemView item = items.get(req.itemId());
        if (item == null || !"ACTIVE".equals(item.status()) || !item.available()) {
            throw BhookException.notFound("Item not available");
        }
        long unit = computeUnitPriceMinor(item, req.variantId(), req.modifierIds());

        Cart cart = cartRepository.findByUserIdAndVendorId(me.userId(), req.vendorId())
                .orElseGet(() -> cartRepository.save(Cart.builder()
                        .userId(me.userId())
                        .campusId(me.activeCampusId())
                        .vendorId(req.vendorId())
                        .build()));

        List<CartItem> existingLines = cartItemRepository.findByCartIdOrderByCreatedAtAsc(cart.getId());
        String modifierIdsJson = writeUuidList(req.modifierIds());
        CartItem match = existingLines.stream()
                .filter(l -> l.getItemId().equals(req.itemId())
                        && Objects.equals(l.getVariantId(), req.variantId())
                        && Objects.equals(nullSafe(l.getModifierIds()), modifierIdsJson))
                .findFirst()
                .orElse(null);

        if (match != null) {
            match.setQuantity(match.getQuantity() + req.quantity());
            match.setUnitPriceMinor(unit);
            cartItemRepository.save(match);
        } else {
            cartItemRepository.save(CartItem.builder()
                    .cartId(cart.getId())
                    .itemId(req.itemId())
                    .variantId(req.variantId())
                    .modifierIds(modifierIdsJson)
                    .quantity(req.quantity())
                    .unitPriceMinor(unit)
                    .build());
        }
        cartRepository.save(cart);
        return toResponse(cart);
    }

    @Transactional
    public CartResponse removeLine(String bearer, UUID vendorId, UUID lineId) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        Cart cart = cartRepository.findByUserIdAndVendorId(me.userId(), vendorId)
                .orElseThrow(() -> BhookException.notFound("Cart not found"));
        CartItem line = cartItemRepository.findById(lineId)
                .orElseThrow(() -> BhookException.notFound("Line not found"));
        if (!line.getCartId().equals(cart.getId())) {
            throw BhookException.forbidden("Line does not belong to this cart");
        }
        cartItemRepository.delete(line);
        cartRepository.save(cart);
        return toResponse(cart);
    }

    @Transactional
    public CartResponse setLineQuantity(String bearer, UUID vendorId, UUID lineId, int quantity) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        Cart cart = cartRepository.findByUserIdAndVendorId(me.userId(), vendorId)
                .orElseThrow(() -> BhookException.notFound("Cart not found"));
        CartItem line = cartItemRepository.findById(lineId)
                .orElseThrow(() -> BhookException.notFound("Line not found"));
        if (!line.getCartId().equals(cart.getId())) {
            throw BhookException.forbidden("Line does not belong to this cart");
        }
        if (quantity <= 0) {
            cartItemRepository.delete(line);
            if (!cartItemRepository.existsByCartId(cart.getId())) {
                cartRepository.delete(cart);
                return new CartResponse(null, me.userId(), me.activeCampusId(), vendorId, 0, List.of());
            }
        } else {
            line.setQuantity(quantity);
            cartItemRepository.save(line);
        }
        cartRepository.save(cart);
        return toResponse(cart);
    }

    @Transactional(readOnly = true)
    public CartResponse get(String bearer, UUID vendorId) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        return cartRepository.findByUserIdAndVendorId(me.userId(), vendorId)
            .map(this::toResponse)
            .orElseGet(() -> new CartResponse(
                null, me.userId(), me.activeCampusId(), vendorId, 0, List.of()));
    }

    @Transactional
    public void clear(String bearer) {
        CustomerProfileView me = contextResolver.requireVerifiedCustomer(bearer);
        for (Cart c : cartRepository.findByUserId(me.userId())) {
            cartItemRepository.deleteByCartId(c.getId());
            cartRepository.delete(c);
        }
    }

    long computeUnitPriceMinor(CatalogView.ItemView item, UUID variantId, List<UUID> modifierIds) {
        long unit = item.offerPriceMinor() != null && item.offerEndsAt() != null
            && item.offerEndsAt().isAfter(java.time.Instant.now())
            ? item.offerPriceMinor() : item.priceMinor();
        if (variantId != null) {
            unit += item.variants().stream()
                    .filter(v -> v.id().equals(variantId))
                    .findFirst()
                    .orElseThrow(() -> BhookException.notFound("Variant not available"))
                    .priceDeltaMinor();
        }
        if (modifierIds != null && !modifierIds.isEmpty()) {
            for (UUID mid : modifierIds) {
                unit += item.modifiers().stream()
                        .filter(m -> m.id().equals(mid))
                        .findFirst()
                        .orElseThrow(() -> BhookException.notFound("Modifier not available"))
                        .priceDeltaMinor();
            }
        }
        return unit;
    }

    private CartResponse toResponse(Cart cart) {
        List<CartItem> lines = cartItemRepository.findByCartIdOrderByCreatedAtAsc(cart.getId());
        return new CartResponse(
                cart.getId(), cart.getUserId(), cart.getCampusId(), cart.getVendorId(),
                cart.getVersion() == null ? 0 : cart.getVersion(),
                lines.stream().map(l -> new CartResponse.CartLine(
                        l.getId(), l.getItemId(), l.getVariantId(),
                        readUuidList(l.getModifierIds()),
                        l.getQuantity(), l.getUnitPriceMinor(),
                        l.getUnitPriceMinor() * l.getQuantity()
                )).toList()
        );
    }

    private String nullSafe(String s) {
        return s == null ? "[]" : s;
    }

    private String writeUuidList(List<UUID> ids) {
        try {
            return ids == null ? "[]" : objectMapper.writeValueAsString(ids);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize modifier ids", e);
        }
    }

    @SuppressWarnings("unchecked")
    private List<UUID> readUuidList(String json) {
        try {
            if (json == null || json.isBlank()) return List.of();
            return objectMapper.readValue(json, objectMapper.getTypeFactory().constructCollectionType(List.class, UUID.class));
        } catch (Exception e) {
            return List.of();
        }
    }
}
