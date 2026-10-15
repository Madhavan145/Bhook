package com.bhook.identity.api.dto;

import java.util.List;
import java.util.UUID;

public record UserSummary(
        UUID userId,
        String email,
        String displayName,
        String status,
        List<String> roles
) {}
