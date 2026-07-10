package com.bhook.delivery.service;

import com.bhook.delivery.domain.DeliveryJob;
import com.bhook.delivery.domain.DeliveryPartner;
import com.bhook.delivery.domain.JobStatus;
import com.bhook.delivery.repository.DeliveryJobRepository;
import com.bhook.delivery.repository.DeliveryPartnerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class DeliveryOfferReaper {

    private final DeliveryJobRepository jobRepository;
    private final DeliveryPartnerRepository partnerRepository;
    private final DeliveryService deliveryService;

    @Value("${bhook.delivery.offer-ttl-seconds:30}")
    private long offerTtlSeconds;

    @Scheduled(fixedDelayString = "${bhook.delivery.offer-scan-ms:5000}")
    @Transactional
    public void reap() {
        Instant cutoff = Instant.now().minusSeconds(offerTtlSeconds);
        List<DeliveryJob> stale = jobRepository.findByStatusAndAssignedAtBefore(JobStatus.OFFERED, cutoff);
        for (DeliveryJob job : stale) {
            if (job.getPartnerId() != null) {
                partnerRepository.findById(job.getPartnerId()).ifPresent(this::release);
            }
            log.info("Offer for job {} expired after {}s; reassigning", job.getId(), offerTtlSeconds);
            job.setStatus(JobStatus.PENDING_ASSIGNMENT);
            job.setPartnerId(null);
            job.setAssignedAt(null);
            DeliveryJob saved = jobRepository.save(job);
            deliveryService.assignNext(saved);
        }
    }

    private void release(DeliveryPartner partner) {
        if (partner.getActiveTaskCount() > 0) {
            partner.setActiveTaskCount(partner.getActiveTaskCount() - 1);
            partnerRepository.save(partner);
        }
    }
}
