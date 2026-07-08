package com.bhook.delivery.repository;

import com.bhook.delivery.domain.DeliveryJob;
import com.bhook.delivery.domain.JobStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeliveryJobRepository extends JpaRepository<DeliveryJob, UUID> {
    Optional<DeliveryJob> findByOrderId(UUID orderId);
    List<DeliveryJob> findByPartnerIdAndStatusInOrderByCreatedAtAsc(UUID partnerId, List<JobStatus> statuses);
    List<DeliveryJob> findByStatusAndAssignedAtBefore(JobStatus status, Instant assignedBefore);
}
