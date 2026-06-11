package com.bhook.catalog.repository;

import com.bhook.catalog.domain.CatalogItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CatalogItemRepository extends JpaRepository<CatalogItem, UUID> {
    List<CatalogItem> findByVendorIdAndArchivedFalseOrderByCreatedAtAsc(UUID vendorId);
    List<CatalogItem> findByCategoryIdAndArchivedFalseOrderByCreatedAtAsc(UUID categoryId);
}
