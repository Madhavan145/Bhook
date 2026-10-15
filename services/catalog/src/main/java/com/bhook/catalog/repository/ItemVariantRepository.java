package com.bhook.catalog.repository;

import com.bhook.catalog.domain.ItemVariant;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ItemVariantRepository extends JpaRepository<ItemVariant, UUID> {
    List<ItemVariant> findByItemIdOrderByCreatedAtAsc(UUID itemId);
}
