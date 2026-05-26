package com.bhook.campus.api.dto;

import com.bhook.campus.domain.CampusStatus;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record UpdateCampusRequest(
        @Size(max = 128) String name,
        @Size(max = 128) String displayName,
        @Size(max = 64) String country,
        @Size(max = 128) String region,
        @Size(max = 64) String timezone,
        @Size(max = 8) String currency,
        BigDecimal latitude,
        BigDecimal longitude,
        CampusStatus status,
        Boolean deliveryEnabled,
        Boolean hostelPickupEnabled,
        Boolean partnerAccessEnabled
        , Long platformFeeMinor
) {}