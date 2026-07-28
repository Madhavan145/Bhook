package com.bhook.social.service;

import com.bhook.common.error.BhookException;
import com.bhook.social.api.dto.FriendshipView;
import com.bhook.social.client.CustomerClient;
import com.bhook.social.domain.Friendship;
import com.bhook.social.domain.FriendshipStatus;
import com.bhook.social.repository.FriendshipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.Comparator;

@Service
@RequiredArgsConstructor
public class FriendshipService {

    private final FriendshipRepository repository;
    private final CustomerClient customerClient;

    @Transactional
    public Friendship request(UUID actor, String bearer, String friendCode) {
        CustomerClient.CustomerProfile requester = customerClient.getMe(bearer);
        CustomerClient.CustomerProfile target = customerClient.getByCode(bearer, friendCode);
        if (requester.activeCampusId() == null || !requester.activeCampusId().equals(target.activeCampusId())) {
            throw BhookException.forbidden("Friendships are limited to the same campus");
        }
        return request(actor, target.userId(), requester.activeCampusId());
    }

    private Friendship request(UUID actor, UUID targetUserId, UUID campusId) {
        if (actor.equals(targetUserId)) {
            throw BhookException.validation("Cannot send a friend request to yourself");
        }
        UUID a = orderedLow(actor, targetUserId);
        UUID b = orderedHigh(actor, targetUserId);
        Friendship existing = repository.findByUserAIdAndUserBId(a, b).orElse(null);
        if (existing != null) {
            if (existing.getStatus() == FriendshipStatus.ACCEPTED) return existing;
            if (existing.getStatus() == FriendshipStatus.PENDING) {
                if (existing.getRequestedBy().equals(actor)) return existing;
                throw BhookException.conflict("You have an incoming friend request to review");
            }
            if (existing.getStatus() == FriendshipStatus.BLOCKED) {
                throw BhookException.forbidden("Friend request is blocked");
            }
            existing.setStatus(FriendshipStatus.PENDING);
            existing.setRequestedBy(actor);
                existing.setCampusId(campusId);
            existing.setRespondedAt(null);
            return repository.save(existing);
        }
        return repository.save(Friendship.builder()
                .userAId(a).userBId(b)
                .requestedBy(actor)
                .campusId(campusId)
                .status(FriendshipStatus.PENDING)
                .build());
    }

    @Transactional
    public Friendship respond(UUID actor, UUID friendshipId, boolean accept) {
        Friendship f = repository.findById(friendshipId)
                .orElseThrow(() -> BhookException.notFound("Friend request not found"));
        if (!f.getUserAId().equals(actor) && !f.getUserBId().equals(actor)) {
            throw BhookException.forbidden("Not a party to this friend request");
        }
        if (f.getRequestedBy().equals(actor)) {
            throw BhookException.forbidden("Cannot respond to your own request");
        }
        if (f.getStatus() != FriendshipStatus.PENDING) {
            throw BhookException.conflict("Request is not pending");
        }
        f.setStatus(accept ? FriendshipStatus.ACCEPTED : FriendshipStatus.DECLINED);
        f.setRespondedAt(Instant.now());
        return repository.save(f);
    }

    @Transactional
    public void remove(UUID actor, UUID friendshipId) {
        Friendship f = repository.findById(friendshipId)
                .orElseThrow(() -> BhookException.notFound("Friendship not found"));
        if (!f.getUserAId().equals(actor) && !f.getUserBId().equals(actor)) {
            throw BhookException.forbidden("Not a party to this friendship");
        }
        repository.delete(f);
    }

    @Transactional
    public Friendship block(UUID actor, UUID targetUserId) {
        UUID a = orderedLow(actor, targetUserId);
        UUID b = orderedHigh(actor, targetUserId);
        Friendship f = repository.findByUserAIdAndUserBId(a, b)
                .orElseGet(() -> Friendship.builder()
                        .userAId(a).userBId(b).requestedBy(actor)
                        .status(FriendshipStatus.PENDING).build());
        f.setStatus(FriendshipStatus.BLOCKED);
        return repository.save(f);
    }

    public List<Friendship> listAccepted(UUID userId) {
        return repository.findAllForUserWithStatus(userId, FriendshipStatus.ACCEPTED);
    }

    public List<Friendship> listIncomingPending(UUID userId) {
        return repository.findIncomingPending(userId);
    }

        public List<FriendshipView> relationships(UUID userId, String bearer) {
        UUID campusId = customerClient.getMe(bearer).activeCampusId();
        return repository.findAllForUser(userId).stream()
            .filter(friendship -> campusId != null && campusId.equals(friendship.getCampusId()))
            .sorted(Comparator.comparing(Friendship::getCreatedAt).reversed())
            .map(friendship -> {
                UUID otherUserId = friendship.getUserAId().equals(userId)
                    ? friendship.getUserBId() : friendship.getUserAId();
                CustomerClient.CustomerProfile profile = customerClient.getByCode(bearer, otherUserId.toString());
                return new FriendshipView(
                    friendship.getId(), otherUserId,
                    friendship.getRequestedBy(), friendship.getCampusId(),
                    friendship.getStatus().name(),
                    friendship.getStatus() == FriendshipStatus.PENDING
                        ? (friendship.getRequestedBy().equals(userId) ? "OUTGOING" : "INCOMING")
                        : "NONE",
                    profile.displayName(), profile.profileImageObjectKey());
            })
            .toList();
        }

    public boolean areFriends(UUID a, UUID b) {
        if (a.equals(b)) return false;
        return repository.findByUserAIdAndUserBId(orderedLow(a, b), orderedHigh(a, b))
                .map(f -> f.getStatus() == FriendshipStatus.ACCEPTED)
                .orElse(false);
    }

    private static UUID orderedLow(UUID a, UUID b) {
        return a.compareTo(b) < 0 ? a : b;
    }
    private static UUID orderedHigh(UUID a, UUID b) {
        return a.compareTo(b) < 0 ? b : a;
    }
}
