package com.bhook.catalog.repository;

import com.bhook.catalog.domain.Menu;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MenuRepository extends JpaRepository<Menu, UUID> {
    List<Menu> findByVendorIdOrderByCreatedAtAsc(UUID vendorId);
}
