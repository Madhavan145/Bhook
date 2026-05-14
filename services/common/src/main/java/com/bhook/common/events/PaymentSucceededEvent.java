package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record PaymentSucceededEvent(
        UUID paymentAttemptId,
        UUID orderId,
        String provider,
        String providerReference,
        long amountMinor,
        String currency,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "payment.succeeded";
}
