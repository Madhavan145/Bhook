package com.bhook.identity.client;

import java.util.List;
import java.util.UUID;

public record CampusDomainLookup(String domain, List<Match> matches) {
    public record Match(
            UUID campusId,
            String campusName,
            String membershipType,
            boolean autoVerify
    ) {}
}
