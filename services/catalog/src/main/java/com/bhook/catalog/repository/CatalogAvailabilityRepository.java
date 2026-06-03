package com.bhook.catalog.repository;

import com.bhook.catalog.domain.CatalogAvailability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface CatalogAvailabilityRepository extends JpaRepository<CatalogAvailability, UUID> {
    Optional<CatalogAvailability> findByItemId(UUID itemId);
}
