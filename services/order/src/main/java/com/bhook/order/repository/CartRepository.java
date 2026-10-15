package com.bhook.order.repository;

import com.bhook.order.domain.Cart;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CartRepository extends JpaRepository<Cart, UUID> {
    Optional<Cart> findByUserIdAndVendorId(UUID userId, UUID vendorId);

    List<Cart> findByUserId(UUID userId);

}
