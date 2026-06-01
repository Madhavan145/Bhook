package com.bhook.campus.api.dto;

import com.bhook.campus.domain.CampusStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;

public record CreateCampusRequest(
        @NotBlank @Size(max = 128) String name,
        @NotBlank @Size(max = 128) String displayName,
        @NotBlank @Size(max = 64) String country,
        @Size(max = 128) String region,
        @NotBlank @Size(max = 64) String timezone,
        @NotBlank @Size(max = 8) String currency,
        BigDecimal latitude,
        BigDecimal longitude,
        @NotNull CampusStatus status,
        boolean deliveryEnabled,
        boolean hostelPickupEnabled,
        boolean partnerAccessEnabled,
        Long platformFeeMinor,
        @Valid List<EmailDomainRequest> emailDomains
) {}
