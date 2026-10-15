package com.bhook.order.repository;

import com.bhook.order.domain.OrderEntity;
import com.bhook.order.domain.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.time.Instant;
import java.util.UUID;

public interface OrderRepository extends JpaRepository<OrderEntity, UUID> {
    List<OrderEntity> findByUserIdOrderByCreatedAtDesc(UUID userId);
        List<OrderEntity> findByVendorIdAndStatusInOrderByCreatedAtDesc(UUID vendorId, List<OrderStatus> statuses);
    List<OrderEntity> findByVendorIdOrderByCreatedAtDesc(UUID vendorId);
        List<OrderEntity> findByVendorIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
            UUID vendorId, Instant from, Instant to);

    List<OrderEntity> findByStatusOrderByCreatedAtDesc(OrderStatus status);
}
