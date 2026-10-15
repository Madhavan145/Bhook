package com.bhook.identity.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record EmailChallengeRequest(@Email @NotBlank String email) {}
