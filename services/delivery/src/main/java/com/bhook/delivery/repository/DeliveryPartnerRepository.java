package com.bhook.delivery.repository;

import com.bhook.delivery.domain.AvailabilityStatus;
import com.bhook.delivery.domain.DeliveryPartner;
import com.bhook.delivery.domain.PartnerStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeliveryPartnerRepository extends JpaRepository<DeliveryPartner, UUID> {
    Optional<DeliveryPartner> findByUserId(UUID userId);
    List<DeliveryPartner> findByCampusIdAndStatusAndAvailabilityStatusOrderByActiveTaskCountAsc(
            UUID campusId, PartnerStatus status, AvailabilityStatus availability);

    List<DeliveryPartner> findAllByOrderByCreatedAtDesc();
    List<DeliveryPartner> findByCampusIdOrderByCreatedAtDesc(UUID campusId);
    List<DeliveryPartner> findByStatusOrderByCreatedAtDesc(PartnerStatus status);
    List<DeliveryPartner> findByCampusIdAndStatusOrderByCreatedAtDesc(UUID campusId, PartnerStatus status);

    long countByStatus(PartnerStatus status);
    long countByAvailabilityStatus(AvailabilityStatus availabilityStatus);
}
