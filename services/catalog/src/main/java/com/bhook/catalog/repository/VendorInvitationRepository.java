package com.bhook.catalog.repository;

import com.bhook.catalog.domain.VendorInvitation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface VendorInvitationRepository extends JpaRepository<VendorInvitation, UUID> {
    Optional<VendorInvitation> findByTokenHash(String tokenHash);
}