package com.bhook.catalog.repository;

import com.bhook.catalog.domain.VendorMembership;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface VendorMembershipRepository extends JpaRepository<VendorMembership, UUID> {
    Optional<VendorMembership> findByVendorIdAndUserId(UUID vendorId, UUID userId);
    List<VendorMembership> findByUserId(UUID userId);
    List<VendorMembership> findByVendorId(UUID vendorId);
}
