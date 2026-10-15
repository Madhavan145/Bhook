package com.bhook.identity.api.dto;

import com.bhook.identity.domain.OtpChannel;
import com.bhook.identity.domain.OtpPurpose;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record OtpRequest(
        @NotNull OtpChannel channel,
        @NotNull OtpPurpose purpose,
        @NotBlank String destination
) {}
