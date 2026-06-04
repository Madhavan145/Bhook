package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateVendorApplicationRequest(
        @NotNull UUID campusId,
        @NotBlank @Size(max = 255) String legalName,
        @NotBlank @Size(max = 255) String displayName,
        @Size(max = 2000) String description,
        @Email @Size(max = 255) String contactEmail,
        @Size(max = 32) String contactPhone
) {}
