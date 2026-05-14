package com.bhook.common.security;

import java.util.List;
import java.util.UUID;

public record AuthenticatedPrincipal(
        UUID userId,
        String sessionId,
        List<String> roles,
        List<String> permissions
) {}
