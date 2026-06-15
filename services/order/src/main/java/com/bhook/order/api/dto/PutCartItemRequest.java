package com.bhook.order.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.util.List;
import java.util.UUID;

public record PutCartItemRequest(
        @NotNull UUID vendorId,
        @NotNull UUID itemId,
        UUID variantId,
        List<UUID> modifierIds,
        @Positive int quantity,
        Integer version
) {}
