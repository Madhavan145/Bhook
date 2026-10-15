package com.bhook.campus.api.dto;

import com.bhook.campus.domain.MembershipType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EmailDomainRequest(
        @NotBlank
        @Size(max = 255)
        @Pattern(
                regexp = "^(?!-)[a-z0-9-]+(?:\\.[a-z0-9-]+)+$",
                flags = Pattern.Flag.CASE_INSENSITIVE,
                message = "domain must be a valid DNS domain (e.g. vitstudent.ac.in), no @ prefix, no wildcards"
        )
        String domain,
        @NotNull MembershipType membershipType,
        boolean autoVerify,
        @Size(max = 512) String notes
) {}
