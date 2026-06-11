package com.bhook.catalog.api.dto;

import com.bhook.catalog.domain.VendorLifecycleStatus;

import java.time.Instant;
import java.util.UUID;

public record VendorResponse(
        UUID id,
        UUID campusId,
        String vendorType,
        String legalName,
        String displayName,
        String description,
        String contactEmail,
        String contactPhone,
        VendorLifecycleStatus lifecycleStatus,
        String logoObjectKey,
        String coverObjectKey,
        boolean autoAcceptOrders,
        Double commissionPercent,
        Integer version,
        Instant createdAt,
        Instant updatedAt
) {}
