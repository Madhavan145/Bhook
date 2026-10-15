package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record DeliveryStatusChangedEvent(
        UUID jobId,
        UUID orderId,
        UUID partnerId,
        String fromStatus,
        String toStatus,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "delivery.status-changed";
}
