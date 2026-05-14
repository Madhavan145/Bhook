package com.bhook.common.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;
import java.util.UUID;

public final class AuthContext {

    private AuthContext() {}

    public static Optional<AuthenticatedPrincipal> principal() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthenticatedPrincipal p)) {
            return Optional.empty();
        }
        return Optional.of(p);
    }

    public static UUID requireUserId() {
        return principal()
                .map(AuthenticatedPrincipal::userId)
                .orElseThrow(() -> new IllegalStateException("No authenticated user in context"));
    }
}
