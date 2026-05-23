package com.bhook.identity.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record OtpVerifyRequest(
        @NotNull UUID challengeId,
        @NotBlank String code
) {}
