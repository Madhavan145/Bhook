package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record DeliveryAssignedEvent(
        UUID jobId,
        UUID orderId,
        UUID vendorId,
        UUID campusId,
        UUID partnerId,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "delivery.assigned";
}
