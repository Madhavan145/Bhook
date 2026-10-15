package com.bhook.identity.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CompleteSignupRequest(
        @NotNull UUID challengeId,
        @NotBlank @Size(min = 4, max = 8) String otp,
        @NotBlank @Size(min = 10, max = 128) String password,
        @NotBlank @Size(max = 120) String displayName,
                @NotBlank @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$", message = "Phone must be E.164 format") String phoneE164,
        UUID campusId
) {
        public CompleteSignupRequest {
                phoneE164 = phoneE164 == null ? null : phoneE164.replaceAll("\\s+", "");
        }
}
