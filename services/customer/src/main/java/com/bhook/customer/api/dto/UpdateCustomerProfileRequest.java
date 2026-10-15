package com.bhook.customer.api.dto;

import jakarta.validation.constraints.Size;

public record UpdateCustomerProfileRequest(
        @Size(max = 120) String displayName,
        @Size(max = 500) String bio,
        @Size(max = 512) String profileImageObjectKey
) {}