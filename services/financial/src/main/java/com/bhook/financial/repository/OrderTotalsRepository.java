package com.bhook.financial.repository;

import com.bhook.financial.domain.OrderTotals;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;
import org.springframework.data.jpa.repository.Query;

public interface OrderTotalsRepository extends JpaRepository<OrderTotals, UUID> {
	@Query("SELECT COALESCE(SUM(o.totalMinor), 0) FROM OrderTotals o WHERE o.vendorId = :vendorId AND o.completedAt IS NOT NULL")
	long sumCompletedSales(UUID vendorId);

	@Query("SELECT COALESCE(SUM(o.totalMinor * o.commissionBps / 10000), 0) FROM OrderTotals o WHERE o.vendorId = :vendorId AND o.completedAt IS NOT NULL")
	long sumCompletedCommission(UUID vendorId);
}
