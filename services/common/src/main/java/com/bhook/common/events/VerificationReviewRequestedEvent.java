package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record VerificationReviewRequestedEvent(
        UUID verificationId,
        UUID membershipId,
        UUID userId,
        UUID campusId,
        String submittedEmail,
        String reason,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "customer.verification.review-requested";
}
