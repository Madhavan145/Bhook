package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record CatalogItemChangedEvent(
        UUID itemId,
        UUID vendorId,
        UUID categoryId,
        String changeType,
        long priceMinor,
        long taxMinor,
        String status,
        boolean archived,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "catalog.item.changed";
}
