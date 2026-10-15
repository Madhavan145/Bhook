package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;
import java.time.Instant;

public record CreateItemRequest(
        @NotNull UUID categoryId,
        @NotBlank @Size(max = 200) String name,
        @Size(max = 2000) String description,
        @PositiveOrZero long priceMinor,
        @PositiveOrZero Long offerPriceMinor,
        Instant offerEndsAt,
        Boolean offerEnabled,
        @PositiveOrZero long taxMinor,
        Integer prepTimeMinutes,
        String imageObjectKey,
        List<@Size(max = 64) String> dietaryTags
) {}
