package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record OrderCreatedEvent(
        UUID orderId,
        String orderNumber,
        UUID userId,
        UUID vendorId,
        UUID campusId,
        UUID pickupLocationId,
        String currency,
        long totalMinor,
        String paymentMethod,
        Instant occurredAt,
        int commissionBps
) {
    public static final String EVENT_TYPE = "order.created";
}
