package com.bhook.campus.api.dto;

import com.bhook.campus.domain.LocationType;

import java.math.BigDecimal;
import java.util.UUID;

public record UpdateLocationRequest(
        String name,
        LocationType locationType,
        UUID parentId,
        BigDecimal latitude,
        BigDecimal longitude,
        String instructions,
        String status
) {}