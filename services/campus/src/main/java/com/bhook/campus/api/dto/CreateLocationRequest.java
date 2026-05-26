package com.bhook.campus.api.dto;

import com.bhook.campus.domain.LocationType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

public record CreateLocationRequest(
        @NotBlank @Size(max = 150) String name,
        @NotNull LocationType locationType,
        UUID parentId,
        BigDecimal latitude,
        BigDecimal longitude,
        String instructions
) {}
