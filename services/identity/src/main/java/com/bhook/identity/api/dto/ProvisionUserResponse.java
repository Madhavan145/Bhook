package com.bhook.identity.api.dto;

import java.util.List;
import java.util.UUID;

public record ProvisionUserResponse(
        UUID userId,
        String email,
        String displayName,
        List<String> roles,
        String temporaryPassword
) {}
