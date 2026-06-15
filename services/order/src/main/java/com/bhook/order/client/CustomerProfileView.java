package com.bhook.order.client;

import java.util.UUID;

public record CustomerProfileView(
        UUID userId,
        UUID activeCampusId,
        String verificationState,
        String email
) {}
