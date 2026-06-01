package com.bhook.campus.api.dto;

import com.bhook.campus.domain.MembershipType;

import java.util.List;
import java.util.UUID;

public record DomainLookupResponse(String domain, List<Match> matches) {
    public record Match(
            UUID campusId,
            String campusName,
            MembershipType membershipType,
            boolean autoVerify
    ) {}
}
