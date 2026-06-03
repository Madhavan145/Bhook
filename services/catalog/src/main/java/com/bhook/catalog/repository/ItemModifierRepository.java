package com.bhook.catalog.repository;

import com.bhook.catalog.domain.ItemModifier;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ItemModifierRepository extends JpaRepository<ItemModifier, UUID> {
    List<ItemModifier> findByItemIdOrderByCreatedAtAsc(UUID itemId);
}
