package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateVariantRequest(
        @NotBlank @Size(max = 120) String name,
        long priceDeltaMinor
) {}
