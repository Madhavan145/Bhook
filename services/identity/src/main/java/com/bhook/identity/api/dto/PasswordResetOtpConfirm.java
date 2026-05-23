package com.bhook.identity.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordResetOtpConfirm(
        @NotBlank String challengeId,
        @NotBlank @Size(min = 6, max = 8) String otp,
        @NotBlank @Size(min = 10, max = 128) String newPassword
) {}
