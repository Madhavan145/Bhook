package com.bhook.catalog.repository;

import com.bhook.catalog.domain.Category;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CategoryRepository extends JpaRepository<Category, UUID> {
    List<Category> findByMenuIdOrderByDisplayOrderAsc(UUID menuId);
    List<Category> findByVendorIdOrderByDisplayOrderAsc(UUID vendorId);
}
