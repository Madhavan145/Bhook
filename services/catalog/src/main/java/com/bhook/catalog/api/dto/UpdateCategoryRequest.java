package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record UpdateCategoryRequest(
        @Size(max = 120) String name,
        @PositiveOrZero Integer displayOrder
) {}