package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record CustomerSignupCompletedEvent(
        UUID userId,
        String email,
        String phoneE164,
        String displayName,
        UUID campusId,
        String campusName,
        String membershipType,
        boolean autoVerify,
        String verifiedDomain,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "identity.customer.signup-completed";
}
