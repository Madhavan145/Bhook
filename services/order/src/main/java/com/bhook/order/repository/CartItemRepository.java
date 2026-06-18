package com.bhook.order.repository;

import com.bhook.order.domain.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CartItemRepository extends JpaRepository<CartItem, UUID> {
    List<CartItem> findByCartIdOrderByCreatedAtAsc(UUID cartId);
    boolean existsByCartId(UUID cartId);
    void deleteByCartId(UUID cartId);
}
