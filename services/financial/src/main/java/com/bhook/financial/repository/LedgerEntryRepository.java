package com.bhook.financial.repository;

import com.bhook.financial.domain.LedgerEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface LedgerEntryRepository extends JpaRepository<LedgerEntry, UUID> {

    Optional<LedgerEntry> findByOrderIdAndEntryType(UUID orderId, String entryType);

    List<LedgerEntry> findByVendorIdOrderByCreatedAtDesc(UUID vendorId);

    List<LedgerEntry> findByOrderIdOrderByCreatedAtAsc(UUID orderId);

    @Query("SELECT COALESCE(SUM(l.amountMinor), 0) FROM LedgerEntry l WHERE l.vendorId = :vendorId AND l.entryType = :entryType")
    long sumForVendorByType(UUID vendorId, String entryType);
}
