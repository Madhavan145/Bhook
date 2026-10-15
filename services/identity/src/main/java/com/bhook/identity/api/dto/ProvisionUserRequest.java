package com.bhook.identity.api.dto;

import com.bhook.identity.domain.RoleName;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public record ProvisionUserRequest(
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank @Size(max = 120) String displayName,
        @Size(max = 32) String phoneE164,
        @NotEmpty List<RoleName> roles,
        @Size(min = 8, max = 100) String password
) {}
