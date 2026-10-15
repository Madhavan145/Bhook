package com.bhook.operations.repository;

import com.bhook.operations.domain.AuditEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface AuditEntryRepository extends JpaRepository<AuditEntry, UUID> {
    Page<AuditEntry> findByEventType(String eventType, Pageable pageable);
    Page<AuditEntry> findByAggregateTypeAndAggregateId(String aggregateType, String aggregateId, Pageable pageable);
}
