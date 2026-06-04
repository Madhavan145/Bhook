package com.bhook.catalog.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OfferView(
        UUID itemId,
        UUID vendorId,
        String vendorName,
        String name,
        String description,
        long priceMinor,
        long offerPriceMinor,
        Instant offerEndsAt,
        String imageObjectKey,
        List<String> dietaryTags,
        boolean available
) {
}
