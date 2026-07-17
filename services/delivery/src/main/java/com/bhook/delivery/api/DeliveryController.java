package com.bhook.delivery.api;

import com.bhook.common.security.AuthContext;
import com.bhook.delivery.domain.AvailabilityStatus;
import com.bhook.delivery.domain.DeliveryJob;
import com.bhook.delivery.domain.DeliveryPartner;
import com.bhook.delivery.domain.JobStatus;
import com.bhook.delivery.repository.DeliveryJobRepository;
import com.bhook.delivery.repository.DeliveryPartnerRepository;
import com.bhook.delivery.service.DeliveryService;
import com.bhook.common.error.BhookException;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/delivery")
@RequiredArgsConstructor
public class DeliveryController {

    private final DeliveryService deliveryService;
    private final DeliveryPartnerRepository partnerRepository;
    private final DeliveryJobRepository jobRepository;

    @PostMapping("/partners/register")
    public ResponseEntity<DeliveryPartner> register(@RequestBody RegisterRequest req) {
        return ResponseEntity.status(201).body(deliveryService.register(AuthContext.requireUserId(), req.campusId()));
    }

    @GetMapping("/partners/me")
    public DeliveryPartner me() {
        return partnerRepository.findByUserId(AuthContext.requireUserId())
                .orElseThrow(() -> BhookException.notFound("Partner profile not found"));
    }

    @PutMapping("/partners/me/availability")
    public DeliveryPartner availability(@RequestBody AvailabilityRequest req) {
        return deliveryService.setAvailability(AuthContext.requireUserId(), req.status());
    }

    @GetMapping("/jobs")
    public List<DeliveryJob> myJobs() {
        DeliveryPartner p = partnerRepository.findByUserId(AuthContext.requireUserId())
                .orElseThrow(() -> BhookException.notFound("Partner profile not found"));
        return jobRepository.findByPartnerIdAndStatusInOrderByCreatedAtAsc(p.getId(),
                List.of(JobStatus.OFFERED, JobStatus.ACCEPTED, JobStatus.PICKED_UP, JobStatus.OUT_FOR_DELIVERY));
    }

    @PostMapping("/jobs/{jobId}/accept")
    public DeliveryJob accept(@PathVariable UUID jobId) {
        return deliveryService.accept(AuthContext.requireUserId(), jobId);
    }

    @PostMapping("/jobs/{jobId}/reject")
    public DeliveryJob reject(@PathVariable UUID jobId) {
        return deliveryService.reject(AuthContext.requireUserId(), jobId);
    }

    @PostMapping("/jobs/{jobId}/pickup")
    public DeliveryJob pickup(@PathVariable UUID jobId) {
        return deliveryService.markPickedUp(AuthContext.requireUserId(), jobId);
    }

    @PostMapping("/jobs/{jobId}/handoff")
    public DeliveryJob handoff(@PathVariable UUID jobId) {
        return deliveryService.markHandoff(AuthContext.requireUserId(), jobId);
    }

    public record RegisterRequest(@NotNull UUID campusId) {}
    public record AvailabilityRequest(@NotNull AvailabilityStatus status) {}
}
