package com.bhook.campus.repository;

import com.bhook.campus.domain.CampusEmailDomain;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CampusEmailDomainRepository extends JpaRepository<CampusEmailDomain, UUID> {

    List<CampusEmailDomain> findByCampusIdOrderByDomainAsc(UUID campusId);

    Optional<CampusEmailDomain> findByCampusIdAndDomain(UUID campusId, String domain);

    List<CampusEmailDomain> findByDomainAndStatus(String domain, String status);
}
