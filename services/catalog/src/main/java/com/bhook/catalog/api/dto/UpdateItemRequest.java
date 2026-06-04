package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.time.Instant;

public record UpdateItemRequest(
        @Size(max = 200) String name,
        @Size(max = 2000) String description,
        @PositiveOrZero Long priceMinor,
        @PositiveOrZero Long offerPriceMinor,
        Instant offerEndsAt,
        Boolean offerEnabled,
        @PositiveOrZero Long taxMinor,
        Integer prepTimeMinutes,
        String imageObjectKey,
        List<@Size(max = 64) String> dietaryTags,
        String status
) {}
