package com.bhook.catalog.api.dto;

import java.time.Instant;

public record AdminVendorCreatedResponse(
        VendorResponse vendor,
        String invitationToken,
        Instant invitationExpiresAt
) {}
