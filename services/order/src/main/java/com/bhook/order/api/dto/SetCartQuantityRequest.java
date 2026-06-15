package com.bhook.order.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.UUID;

public record SetCartQuantityRequest(
        @NotNull UUID vendorId,
        @PositiveOrZero int quantity
) {}
