package com.bhook.delivery.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.error.ErrorCode;
import com.bhook.common.events.DeliveryAssignedEvent;
import com.bhook.common.events.DeliveryStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.bhook.delivery.domain.AvailabilityStatus;
import com.bhook.delivery.domain.DeliveryJob;
import com.bhook.delivery.domain.DeliveryPartner;
import com.bhook.delivery.domain.JobStatus;
import com.bhook.delivery.domain.PartnerStatus;
import com.bhook.delivery.outbox.OutboxWriter;
import com.bhook.delivery.repository.DeliveryJobRepository;
import com.bhook.delivery.repository.DeliveryPartnerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeliveryService {

    private final DeliveryPartnerRepository partnerRepository;
    private final DeliveryJobRepository jobRepository;
    private final OutboxWriter outbox;

    @Transactional
    public DeliveryPartner register(UUID userId, UUID campusId) {
        return partnerRepository.findByUserId(userId).orElseGet(() ->
                partnerRepository.save(DeliveryPartner.builder()
                        .userId(userId)
                        .campusId(campusId)
                        .status(PartnerStatus.APPLIED)
                        .availabilityStatus(AvailabilityStatus.OFFLINE)
                        .build())
        );
    }

    @Transactional
    public DeliveryPartner approve(UUID partnerId) {
        DeliveryPartner partner = partnerRepository.findById(partnerId)
                .orElseThrow(() -> BhookException.notFound("Partner not found"));
        partner.setStatus(PartnerStatus.ACTIVE);
        return partnerRepository.save(partner);
    }

    @Transactional
    public DeliveryPartner createByPlatform(UUID userId, UUID campusId) {
        return partnerRepository.findByUserId(userId).map(existing -> {
            existing.setCampusId(campusId);
            existing.setStatus(PartnerStatus.ACTIVE);
            return partnerRepository.save(existing);
        }).orElseGet(() -> partnerRepository.save(DeliveryPartner.builder()
                .userId(userId)
                .campusId(campusId)
                .status(PartnerStatus.ACTIVE)
                .availabilityStatus(AvailabilityStatus.OFFLINE)
                .build()));
    }

    @Transactional(readOnly = true)
    public List<DeliveryPartner> list(UUID campusId, PartnerStatus status) {
        if (campusId != null && status != null) {
            return partnerRepository.findByCampusIdAndStatusOrderByCreatedAtDesc(campusId, status);
        }
        if (campusId != null) {
            return partnerRepository.findByCampusIdOrderByCreatedAtDesc(campusId);
        }
        if (status != null) {
            return partnerRepository.findByStatusOrderByCreatedAtDesc(status);
        }
        return partnerRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional
    public DeliveryPartner setStatus(UUID partnerId, PartnerStatus status) {
        DeliveryPartner partner = partnerRepository.findById(partnerId)
                .orElseThrow(() -> BhookException.notFound("Partner not found"));
        partner.setStatus(status);
        if (status != PartnerStatus.ACTIVE) {
            partner.setAvailabilityStatus(AvailabilityStatus.OFFLINE);
        }
        return partnerRepository.save(partner);
    }

    @Transactional(readOnly = true)
    public PartnerSummary summary() {
        return new PartnerSummary(
                partnerRepository.count(),
                partnerRepository.countByStatus(PartnerStatus.APPLIED),
                partnerRepository.countByStatus(PartnerStatus.ACTIVE),
                partnerRepository.countByStatus(PartnerStatus.SUSPENDED),
                partnerRepository.countByAvailabilityStatus(AvailabilityStatus.ONLINE));
    }

    public record PartnerSummary(long total, long applied, long active, long suspended, long online) {}

    @Transactional
    public DeliveryPartner setAvailability(UUID userId, AvailabilityStatus availability) {
        DeliveryPartner partner = partnerRepository.findByUserId(userId)
                .orElseThrow(() -> BhookException.notFound("Partner profile not found"));
        if (partner.getStatus() != PartnerStatus.ACTIVE) {
            throw BhookException.forbidden("Partner not active");
        }
        partner.setAvailabilityStatus(availability);
        return partnerRepository.save(partner);
    }

    @Transactional
    public DeliveryJob createAndDispatch(UUID orderId, UUID vendorId, UUID campusId) {
        DeliveryJob existing = jobRepository.findByOrderId(orderId).orElse(null);
        if (existing != null) return existing;

        DeliveryJob job = DeliveryJob.builder()
                .orderId(orderId).vendorId(vendorId).campusId(campusId)
                .status(JobStatus.PENDING_ASSIGNMENT)
                .build();
        job = jobRepository.save(job);
        return assignNext(job);
    }

    @Transactional
    public DeliveryJob assignNext(DeliveryJob job) {
        List<DeliveryPartner> candidates = partnerRepository
                .findByCampusIdAndStatusAndAvailabilityStatusOrderByActiveTaskCountAsc(
                        job.getCampusId(), PartnerStatus.ACTIVE, AvailabilityStatus.ONLINE);
        if (candidates.isEmpty()) {
            log.info("No available partner for job {} in campus {}", job.getId(), job.getCampusId());
            return job;
        }
        DeliveryPartner chosen = candidates.get(0);
        job.setPartnerId(chosen.getId());
        job.setStatus(JobStatus.OFFERED);
        job.setAssignedAt(Instant.now());
        chosen.setActiveTaskCount(chosen.getActiveTaskCount() + 1);
        partnerRepository.save(chosen);
        DeliveryJob saved = jobRepository.save(job);

        outbox.write(Topics.DELIVERY_EVENTS, "DeliveryJob", saved.getId().toString(),
                DeliveryAssignedEvent.EVENT_TYPE,
                new DeliveryAssignedEvent(saved.getId(), saved.getOrderId(), saved.getVendorId(),
                        saved.getCampusId(), chosen.getId(), Instant.now()));
        return saved;
    }

    @Transactional
    public DeliveryJob accept(UUID userId, UUID jobId) {
        return transition(userId, jobId, JobStatus.OFFERED, JobStatus.ACCEPTED, j -> j.setAcceptedAt(Instant.now()));
    }

    @Transactional
    public DeliveryJob reject(UUID userId, UUID jobId) {
        DeliveryJob job = jobRepository.findById(jobId)
                .orElseThrow(() -> BhookException.notFound("Job not found"));
        DeliveryPartner partner = partnerRepository.findByUserId(userId)
                .orElseThrow(() -> BhookException.forbidden("Partner profile not found"));
        if (job.getPartnerId() == null || !job.getPartnerId().equals(partner.getId())) {
            throw BhookException.forbidden("Job is not assigned to this partner");
        }
        if (job.getStatus() != JobStatus.OFFERED) {
            throw new BhookException(ErrorCode.INVALID_STATE_TRANSITION, HttpStatus.CONFLICT,
                    "Cannot reject a job in status " + job.getStatus());
        }
        releaseFromPartner(partner);
        job.setPartnerId(null);
        job.setAssignedAt(null);
        job.setStatus(JobStatus.PENDING_ASSIGNMENT);
        DeliveryJob saved = jobRepository.save(job);
        outbox.write(Topics.DELIVERY_EVENTS, "DeliveryJob", saved.getId().toString(),
                DeliveryStatusChangedEvent.EVENT_TYPE,
                new DeliveryStatusChangedEvent(saved.getId(), saved.getOrderId(),
                        partner.getId(), JobStatus.OFFERED.name(), JobStatus.PENDING_ASSIGNMENT.name(), Instant.now()));
        return assignNext(saved);
    }

    private void releaseFromPartner(DeliveryPartner partner) {
        if (partner.getActiveTaskCount() > 0) {
            partner.setActiveTaskCount(partner.getActiveTaskCount() - 1);
            partnerRepository.save(partner);
        }
    }

    @Transactional
    public DeliveryJob markPickedUp(UUID userId, UUID jobId) {
        return transition(userId, jobId, JobStatus.ACCEPTED, JobStatus.PICKED_UP, j -> j.setPickupAt(Instant.now()));
    }

    @Transactional
    public DeliveryJob markHandoff(UUID userId, UUID jobId) {
        DeliveryJob job = transition(userId, jobId, JobStatus.PICKED_UP, JobStatus.COMPLETED,
                j -> j.setDeliveredAt(Instant.now()));
        DeliveryPartner partner = partnerRepository.findById(job.getPartnerId()).orElse(null);
        if (partner != null) releaseFromPartner(partner);
        return job;
    }

    private DeliveryJob transition(UUID userId, UUID jobId, JobStatus expected, JobStatus target,
                                   java.util.function.Consumer<DeliveryJob> mutator) {
        DeliveryJob job = jobRepository.findById(jobId)
                .orElseThrow(() -> BhookException.notFound("Job not found"));
        DeliveryPartner partner = partnerRepository.findByUserId(userId)
                .orElseThrow(() -> BhookException.forbidden("Partner profile not found"));
        if (job.getPartnerId() == null || !job.getPartnerId().equals(partner.getId())) {
            throw BhookException.forbidden("Job is not assigned to this partner");
        }
        if (job.getStatus() != expected) {
            throw new BhookException(ErrorCode.INVALID_STATE_TRANSITION, HttpStatus.CONFLICT,
                    "Cannot transition from " + job.getStatus() + " to " + target);
        }
        JobStatus from = job.getStatus();
        job.setStatus(target);
        mutator.accept(job);
        DeliveryJob saved = jobRepository.save(job);

        outbox.write(Topics.DELIVERY_EVENTS, "DeliveryJob", saved.getId().toString(),
                DeliveryStatusChangedEvent.EVENT_TYPE,
                new DeliveryStatusChangedEvent(saved.getId(), saved.getOrderId(),
                        saved.getPartnerId(), from.name(), target.name(), Instant.now()));
        return saved;
    }
}
