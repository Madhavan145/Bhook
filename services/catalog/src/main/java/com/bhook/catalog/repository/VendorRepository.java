package com.bhook.catalog.repository;

import com.bhook.catalog.domain.Vendor;
import com.bhook.catalog.domain.VendorLifecycleStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface VendorRepository extends JpaRepository<Vendor, UUID> {
    List<Vendor> findByCampusIdAndLifecycleStatus(UUID campusId, VendorLifecycleStatus status);
    List<Vendor> findByLifecycleStatus(VendorLifecycleStatus status);
}
