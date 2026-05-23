package com.bhook.identity.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @Email @NotBlank String email,
                @NotBlank @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$", message = "Phone must be E.164 format") String phoneE164,
        @NotBlank @Size(min = 10, max = 128) String password,
        @NotBlank @Size(max = 120) String displayName,
        String accountType
) {
        public RegisterRequest {
                phoneE164 = phoneE164 == null ? null : phoneE164.replaceAll("\\s+", "");
        }
}
