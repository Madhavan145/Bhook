package com.bhook.tracking.model;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PartnerLocation(
        UUID partnerId,
        BigDecimal latitude,
        BigDecimal longitude,
        Double heading,
        Double speedMps,
        Instant reportedAt
) {}
