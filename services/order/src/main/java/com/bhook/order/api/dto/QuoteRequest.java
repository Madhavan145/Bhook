package com.bhook.order.api.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record QuoteRequest(
        @NotNull UUID vendorId,
        Integer cartVersion
) {}
