package com.bhook.campus.repository;

import com.bhook.campus.domain.Campus;
import com.bhook.campus.domain.CampusStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CampusRepository extends JpaRepository<Campus, UUID> {
    List<Campus> findByStatus(CampusStatus status);
}
