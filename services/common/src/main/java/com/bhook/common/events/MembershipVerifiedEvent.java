package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record MembershipVerifiedEvent(
        UUID membershipId,
        UUID verificationId,
        UUID userId,
        UUID campusId,
        String matchedMembershipType,
        boolean autoVerified,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "customer.membership.verified";
}
