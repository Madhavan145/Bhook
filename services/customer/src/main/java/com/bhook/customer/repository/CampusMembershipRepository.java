package com.bhook.customer.repository;

import com.bhook.customer.domain.CampusMembership;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CampusMembershipRepository extends JpaRepository<CampusMembership, UUID> {
    List<CampusMembership> findByUserId(UUID userId);
}
