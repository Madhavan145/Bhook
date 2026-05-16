package com.bhook.common.events;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record UserRegisteredEvent(
        UUID userId,
        String email,
        String phoneE164,
        String displayName,
        List<String> roles,
        String status,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "identity.user.registered";
}
