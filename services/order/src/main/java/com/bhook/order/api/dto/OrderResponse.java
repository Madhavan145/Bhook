package com.bhook.order.api.dto;

import com.bhook.order.domain.FulfillmentMode;
import com.bhook.order.domain.OrderStatus;
import com.bhook.order.domain.PaymentState;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OrderResponse(
        UUID orderId,
        String orderNumber,
        OrderStatus status,
        PaymentState paymentState,
        UUID campusId,
        UUID vendorId,
        UUID pickupLocationId,
        FulfillmentMode fulfillmentMode,
        String currency,
        long subtotalMinor,
        long taxMinor,
        long deliveryFeeMinor,
        long platformFeeMinor,
        long discountMinor,
        long totalMinor,
        String paymentMethod,
        String clientReference,
        Integer version,
        Instant expiresAt,
        Instant createdAt,
        List<OrderLine> lines
) {
    public record OrderLine(
            UUID lineId,
            UUID itemId,
            String itemName,
            UUID variantId,
            String variantName,
            int quantity,
            long unitPriceMinor,
            long taxMinor,
            long lineTotalMinor
    ) {}
}
