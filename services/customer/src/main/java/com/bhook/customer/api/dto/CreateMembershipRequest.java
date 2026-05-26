package com.bhook.customer.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateMembershipRequest(
        @NotNull UUID campusId,
        @NotBlank @Size(max = 32) String membershipType
) {}
