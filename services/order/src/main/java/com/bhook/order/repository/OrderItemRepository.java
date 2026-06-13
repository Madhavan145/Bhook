package com.bhook.order.repository;

import com.bhook.order.domain.OrderItemSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface OrderItemRepository extends JpaRepository<OrderItemSnapshot, UUID> {
    List<OrderItemSnapshot> findByOrderId(UUID orderId);

    List<OrderItemSnapshot> findByOrderIdIn(Collection<UUID> orderIds);
}
