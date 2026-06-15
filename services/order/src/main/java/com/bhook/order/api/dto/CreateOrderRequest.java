package com.bhook.order.api.dto;

import com.bhook.order.domain.FulfillmentMode;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateOrderRequest(
        @NotNull UUID vendorId,
        Integer cartVersion,
        UUID pickupLocationId,
        FulfillmentMode fulfillmentMode,
        @Size(max = 32) String paymentMethod,
        @Size(max = 128) String clientReference,
        boolean shareWithFriends
) {}
