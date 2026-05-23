package com.bhook.identity.api.dto;

public record TokenResponse(
        String accessToken,
        String refreshToken,
        long expiresInSeconds,
        UserSummary user
) {}
