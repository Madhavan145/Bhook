package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record VendorLifecycleChangedEvent(
        UUID vendorId,
        UUID campusId,
        String previousStatus,
        String newStatus,
        UUID actorUserId,
        String reason,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "catalog.vendor.lifecycle-changed";
}
