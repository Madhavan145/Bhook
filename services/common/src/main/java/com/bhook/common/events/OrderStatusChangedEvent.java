package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record OrderStatusChangedEvent(
        UUID orderId,
        UUID vendorId,
        UUID userId,
        UUID campusId,
        String fromStatus,
        String toStatus,
        String actorType,
        UUID actorId,
        String reason,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "order.status-changed";
}
