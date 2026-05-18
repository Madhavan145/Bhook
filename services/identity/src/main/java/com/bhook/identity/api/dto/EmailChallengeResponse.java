package com.bhook.identity.api.dto;

import java.util.List;
import java.util.UUID;

public record EmailChallengeResponse(
        UUID challengeId,
        String email,
        long expiresInSeconds,
        List<CampusMatch> campusMatches
) {
    public record CampusMatch(UUID campusId, String campusName, String membershipType, boolean autoVerify) {}
}
