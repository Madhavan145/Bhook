package com.bhook.customer.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record SubmitVerificationRequest(
        @Email @NotBlank String submittedEmail,
        @Size(max = 10) List<@NotBlank @Size(max = 512) String> evidenceObjectKeys
) {}
