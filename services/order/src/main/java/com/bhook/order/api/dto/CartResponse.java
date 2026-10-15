package com.bhook.order.api.dto;

import java.util.List;
import java.util.UUID;

public record CartResponse(
        UUID cartId,
        UUID userId,
        UUID campusId,
        UUID vendorId,
        int version,
        List<CartLine> items
) {
    public record CartLine(
            UUID lineId,
            UUID itemId,
            UUID variantId,
            List<UUID> modifierIds,
            int quantity,
            long unitPriceMinor,
            long lineTotalMinor
    ) {}
}
