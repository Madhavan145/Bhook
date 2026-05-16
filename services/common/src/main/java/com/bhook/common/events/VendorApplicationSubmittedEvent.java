package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record VendorApplicationSubmittedEvent(
        UUID vendorId,
        UUID applicantUserId,
        UUID campusId,
        String legalName,
        String displayName,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "catalog.vendor.application-submitted";
}
