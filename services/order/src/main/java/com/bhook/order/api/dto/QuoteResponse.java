package com.bhook.order.api.dto;

import java.util.List;
import java.util.UUID;

public record QuoteResponse(
        UUID vendorId,
        UUID campusId,
        String currency,
        long subtotalMinor,
        long taxMinor,
        long deliveryFeeMinor,
        long platformFeeMinor,
        long discountMinor,
        long totalMinor,
        int cartVersion,
        List<QuotedLine> lines
) {
    public record QuotedLine(
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
