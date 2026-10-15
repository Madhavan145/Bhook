package com.bhook.common.events;

import java.time.Instant;
import java.util.UUID;

public record RefundProcessedEvent(
        UUID refundId,
        UUID paymentAttemptId,
        UUID orderId,
        String provider,
        long amountMinor,
        String currency,
        String reason,
        Instant occurredAt
) {
    public static final String EVENT_TYPE = "payment.refund-processed";
}
