package com.bhook.catalog.api.dto;

import java.time.Instant;

public record SetAvailabilityRequest(
        boolean available,
        Instant scheduledFrom,
        Instant scheduledTo
) {}
