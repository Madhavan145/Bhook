package com.bhook.customer.api.dto;

import java.util.UUID;

public record CustomerDirectoryEntry(
        UUID userId,
        String displayName,
        String profileImageObjectKey,
        String friendCode,
        java.util.UUID activeCampusId
) {}