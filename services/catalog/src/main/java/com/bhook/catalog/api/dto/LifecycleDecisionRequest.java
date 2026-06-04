package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.Size;

public record LifecycleDecisionRequest(
        @Size(max = 2000) String reason
) {}
