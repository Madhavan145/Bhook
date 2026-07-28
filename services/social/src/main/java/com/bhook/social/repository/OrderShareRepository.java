package com.bhook.social.repository;

import com.bhook.social.domain.OrderShare;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OrderShareRepository extends JpaRepository<OrderShare, UUID> {
    List<OrderShare> findByOrderIdAndStatus(UUID orderId, String status);
    List<OrderShare> findBySharedWithUserIdAndStatusAndExpiresAtAfter(UUID sharedWithUserId, String status, java.time.Instant now);
    Optional<OrderShare> findByOrderIdAndSharedWithUserId(UUID orderId, UUID sharedWithUserId);
}
