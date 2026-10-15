package com.bhook.social.api.dto;

import java.util.UUID;

public record FriendshipView(
        UUID friendshipId,
        UUID otherUserId,
        UUID requestedBy,
        UUID campusId,
        String status,
        String direction,
        String displayName,
        String profileImageObjectKey
) {}