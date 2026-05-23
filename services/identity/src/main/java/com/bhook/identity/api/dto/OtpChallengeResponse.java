package com.bhook.identity.api.dto;

import java.util.UUID;

public record OtpChallengeResponse(UUID challengeId, long expiresInSeconds) {}
