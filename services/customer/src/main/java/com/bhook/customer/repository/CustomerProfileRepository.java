package com.bhook.customer.repository;

import com.bhook.customer.domain.CustomerProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface CustomerProfileRepository extends JpaRepository<CustomerProfile, UUID> {
    Optional<CustomerProfile> findByUserId(UUID userId);

    Optional<CustomerProfile> findByFriendCode(String friendCode);

}
