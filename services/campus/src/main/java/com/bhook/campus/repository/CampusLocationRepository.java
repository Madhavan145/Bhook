package com.bhook.campus.repository;

import com.bhook.campus.domain.CampusLocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CampusLocationRepository extends JpaRepository<CampusLocation, UUID> {
    List<CampusLocation> findByCampusId(UUID campusId);
}
