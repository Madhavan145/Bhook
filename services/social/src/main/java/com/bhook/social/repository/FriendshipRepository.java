package com.bhook.social.repository;

import com.bhook.social.domain.Friendship;
import com.bhook.social.domain.FriendshipStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FriendshipRepository extends JpaRepository<Friendship, UUID> {

    Optional<Friendship> findByUserAIdAndUserBId(UUID userAId, UUID userBId);

    @Query("SELECT f FROM Friendship f WHERE f.userAId = :userId OR f.userBId = :userId")
    List<Friendship> findAllForUser(UUID userId);

    @Query("SELECT f FROM Friendship f WHERE (f.userAId = :userId OR f.userBId = :userId) AND f.status = :status")
    List<Friendship> findAllForUserWithStatus(UUID userId, FriendshipStatus status);

    @Query("SELECT f FROM Friendship f WHERE (f.userAId = :userId OR f.userBId = :userId) AND f.status = 'PENDING' AND f.requestedBy <> :userId")
    List<Friendship> findIncomingPending(UUID userId);
}
