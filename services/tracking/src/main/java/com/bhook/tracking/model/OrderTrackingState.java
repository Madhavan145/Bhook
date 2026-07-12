package com.bhook.tracking.model;

import java.time.Instant;
import java.util.UUID;

public record OrderTrackingState(
        UUID orderId,
        UUID partnerId,
        String status,
        PartnerLocation lastLocation,
        Instant updatedAt
) {}
