package com.bhook.social.service;

import com.bhook.common.error.BhookException;
import com.bhook.social.domain.OrderShare;
import com.bhook.social.domain.Friendship;
import com.bhook.social.repository.OrderShareRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.time.Instant;

@Service
@RequiredArgsConstructor
public class OrderShareService {

    private final OrderShareRepository repository;
    private final FriendshipService friendshipService;

    @Transactional
    public List<OrderShare> shareWithFriends(UUID owner, UUID orderId, ShareSnapshot snapshot) {
        return friendshipService.listAccepted(owner).stream()
                .map(friendship -> otherUser(friendship, owner))
                .map(friend -> share(owner, orderId, friend, snapshot))
                .toList();
    }

    @Transactional
    public OrderShare share(UUID owner, UUID orderId, UUID targetUserId) {
        return share(owner, orderId, targetUserId, ShareSnapshot.empty());
    }

    private OrderShare share(UUID owner, UUID orderId, UUID targetUserId, ShareSnapshot snapshot) {
        if (owner.equals(targetUserId)) {
            throw BhookException.validation("Cannot share an order with yourself");
        }
        if (!friendshipService.areFriends(owner, targetUserId)) {
            throw BhookException.forbidden("Order can only be shared with an accepted friend");
        }
        return repository.findByOrderIdAndSharedWithUserId(orderId, targetUserId).map(existing -> {
            if (!existing.getOwnerUserId().equals(owner)) {
                throw BhookException.forbidden("Order share not owned by you");
            }
            existing.setStatus("ACTIVE");
            applySnapshot(existing, snapshot);
            return repository.save(existing);
        }).orElseGet(() -> repository.save(OrderShare.builder()
                .orderId(orderId)
                .ownerUserId(owner)
                .sharedWithUserId(targetUserId)
                .vendorId(snapshot.vendorId())
                .vendorName(snapshot.vendorName())
                .itemId(snapshot.itemId())
                .itemName(snapshot.itemName())
                .itemImageObjectKey(snapshot.itemImageObjectKey())
                .categoryName(snapshot.categoryName())
                .status("ACTIVE")
                .expiresAt(Instant.now().plusSeconds(24 * 60 * 60))
                .build()));
    }

    @Transactional
    public void revoke(UUID owner, UUID shareId) {
        OrderShare share = repository.findById(shareId)
                .orElseThrow(() -> BhookException.notFound("Share not found"));
        if (!share.getOwnerUserId().equals(owner)) {
            throw BhookException.forbidden("Share not owned by you");
        }
        share.setStatus("REVOKED");
        repository.save(share);
    }

    public List<OrderShare> forOrder(UUID orderId) {
        return repository.findByOrderIdAndStatus(orderId, "ACTIVE");
    }

    public List<OrderShare> sharedWithMe(UUID userId) {
        return repository.findBySharedWithUserIdAndStatusAndExpiresAtAfter(userId, "ACTIVE", Instant.now());
    }

    private void applySnapshot(OrderShare share, ShareSnapshot snapshot) {
        share.setVendorId(snapshot.vendorId());
        share.setVendorName(snapshot.vendorName());
        share.setItemId(snapshot.itemId());
        share.setItemName(snapshot.itemName());
        share.setItemImageObjectKey(snapshot.itemImageObjectKey());
        share.setCategoryName(snapshot.categoryName());
        share.setExpiresAt(Instant.now().plusSeconds(24 * 60 * 60));
    }

    private UUID otherUser(Friendship friendship, UUID owner) {
        return friendship.getUserAId().equals(owner) ? friendship.getUserBId() : friendship.getUserAId();
    }

    public record ShareSnapshot(UUID vendorId, String vendorName, UUID itemId, String itemName,
                                String itemImageObjectKey, String categoryName) {
        public static ShareSnapshot empty() {
            return new ShareSnapshot(null, null, null, null, null, null);
        }
    }
}
