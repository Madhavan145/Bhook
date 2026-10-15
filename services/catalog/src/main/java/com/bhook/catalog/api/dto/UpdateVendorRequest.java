package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;

public record UpdateVendorRequest(
        @Size(max = 255) String legalName,
        @Size(max = 255) String displayName,
        @Size(max = 2000) String description,
        @Email @Size(max = 255) String contactEmail,
        @Size(max = 32) String contactPhone,
        String operatingHours,
        String logoObjectKey,
        String coverObjectKey,
        Boolean autoAcceptOrders,
        @DecimalMin("0.0") @DecimalMax("100.0") Double commissionPercent
) {}
