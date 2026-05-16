package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record MembershipCreatedEvent(
        UUID membershipId,
        UUID userId,
        UUID campusId,
        String membershipType,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "customer.membership.created";
}
