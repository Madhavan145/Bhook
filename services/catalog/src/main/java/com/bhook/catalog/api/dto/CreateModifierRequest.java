package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateModifierRequest(
        @NotBlank @Size(max = 120) String name,
        long priceDeltaMinor
) {}
