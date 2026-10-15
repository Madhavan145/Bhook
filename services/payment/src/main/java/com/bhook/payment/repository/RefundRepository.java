package com.bhook.payment.repository;

import com.bhook.payment.domain.Refund;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RefundRepository extends JpaRepository<Refund, UUID> {
    List<Refund> findByOrderId(UUID orderId);
    Optional<Refund> findByOrderIdAndStatus(UUID orderId, String status);
}
