package com.bhook.order.client;

import java.util.List;
import java.util.UUID;
import java.time.Instant;

public record CatalogView(
        UUID vendorId,
        String vendorName,
        UUID campusId,
        List<MenuView> menus
) {
    public record MenuView(UUID menuId, String name, List<CategoryView> categories) {}
    public record CategoryView(UUID categoryId, String name, int displayOrder, List<ItemView> items) {}
    public record ItemView(
            UUID itemId,
            String name,
            String description,
            long priceMinor,
            Long offerPriceMinor,
            Instant offerEndsAt,
            long taxMinor,
            Integer prepTimeMinutes,
            String imageObjectKey,
            List<String> dietaryTags,
            String status,
            boolean available,
            List<VariantView> variants,
            List<ModifierView> modifiers
    ) {}
    public record VariantView(UUID id, String name, long priceDeltaMinor) {}
    public record ModifierView(UUID id, String name, long priceDeltaMinor) {}
}
