package com.bhook.customer.api.dto;

import com.bhook.customer.domain.VerificationStatus;

import java.time.Instant;
import java.util.UUID;

public record VerificationResponse(
        UUID id,
        UUID membershipId,
        UUID campusId,
        String submittedEmail,
        String domainMatch,
        String matchedMembership,
        boolean autoVerified,
        VerificationStatus status,
        Instant createdAt
) {}
