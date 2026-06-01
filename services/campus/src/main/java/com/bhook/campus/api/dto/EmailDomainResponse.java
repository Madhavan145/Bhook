package com.bhook.campus.api.dto;

import com.bhook.campus.domain.MembershipType;

import java.time.Instant;
import java.util.UUID;

public record EmailDomainResponse(
        UUID id,
        UUID campusId,
        String domain,
        MembershipType membershipType,
        boolean autoVerify,
        String status,
        String notes,
        Instant createdAt,
        Instant updatedAt
) {}
