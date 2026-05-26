package com.bhook.customer.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.events.MembershipCreatedEvent;
import com.bhook.common.events.MembershipVerifiedEvent;
import com.bhook.common.events.Topics;
import com.bhook.common.events.VerificationReviewRequestedEvent;
import com.bhook.customer.api.dto.CreateMembershipRequest;
import com.bhook.customer.api.dto.SubmitVerificationRequest;
import com.bhook.customer.api.dto.VerificationResponse;
import com.bhook.customer.client.CampusClient;
import com.bhook.customer.client.CampusDomainLookup;
import com.bhook.customer.domain.CampusMembership;
import com.bhook.customer.domain.CustomerProfile;
import com.bhook.customer.domain.MembershipVerification;
import com.bhook.customer.domain.VerificationStatus;
import com.bhook.customer.outbox.OutboxWriter;
import com.bhook.customer.repository.CampusMembershipRepository;
import com.bhook.customer.repository.CustomerProfileRepository;
import com.bhook.customer.repository.MembershipVerificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class VerificationService {

    private final CustomerProfileRepository profileRepository;
    private final CampusMembershipRepository membershipRepository;
    private final MembershipVerificationRepository verificationRepository;
    private final CampusClient campusClient;
    private final OutboxWriter outbox;

    @Transactional
    public void bootstrapFromSignup(UUID userId, String email, String phoneE164, String displayName,
                                    UUID campusId, String membershipType, boolean autoVerify, String verifiedDomain) {
        profileRepository.findByUserId(userId).orElseGet(() ->
                profileRepository.save(com.bhook.customer.domain.CustomerProfile.builder()
                        .userId(userId)
                        .friendCode(userId.toString())
                        .displayName(displayName)
                        .email(email != null ? email.toLowerCase() : null)
                        .phoneE164(phoneE164)
                        .activeCampusId(campusId)
                        .verificationState(autoVerify ? VerificationStatus.AUTO_VERIFIED.name() : VerificationStatus.PENDING_REVIEW.name())
                        .build())
        );

        VerificationStatus resolvedStatus = autoVerify ? VerificationStatus.AUTO_VERIFIED : VerificationStatus.PENDING_REVIEW;
        CampusMembership membership = membershipRepository.findByUserId(userId).stream()
                .filter(m -> m.getCampusId().equals(campusId))
                .findFirst()
                .orElseGet(() -> membershipRepository.save(CampusMembership.builder()
                        .userId(userId)
                        .campusId(campusId)
                        .membershipType(membershipType)
                        .verificationStatus(resolvedStatus.name())
                        .verificationMethod("EMAIL_DOMAIN")
                        .validFrom(Instant.now())
                        .isActive(autoVerify)
                        .build()));
        membership.setVerificationStatus(resolvedStatus.name());
        membership.setVerificationMethod("EMAIL_DOMAIN");
        membership.setActive(autoVerify);
        membership = membershipRepository.save(membership);

        MembershipVerification verification = verificationRepository.save(MembershipVerification.builder()
                .membershipId(membership.getId())
                .userId(userId)
                .campusId(campusId)
                .submittedEmail(email)
                .evidenceObjectKeys(List.of())
                .domainMatch(verifiedDomain)
                .matchedMembership(membershipType)
                .autoVerified(autoVerify)
                .status(resolvedStatus)
                .build());

        outbox.write(
                Topics.CUSTOMER_EVENTS, "Membership", membership.getId().toString(),
                MembershipCreatedEvent.EVENT_TYPE,
                new MembershipCreatedEvent(membership.getId(), userId, campusId, membershipType, Instant.now())
        );

        if (autoVerify) {
            outbox.write(
                    Topics.CUSTOMER_EVENTS, "Membership", membership.getId().toString(),
                    MembershipVerifiedEvent.EVENT_TYPE,
                    new MembershipVerifiedEvent(membership.getId(), verification.getId(), userId, campusId,
                            membershipType, true, Instant.now())
            );
        } else {
            outbox.write(
                    Topics.CUSTOMER_EVENTS, "Verification", verification.getId().toString(),
                    VerificationReviewRequestedEvent.EVENT_TYPE,
                    new VerificationReviewRequestedEvent(verification.getId(), membership.getId(), userId, campusId,
                            email, "REVIEW_REQUIRED", Instant.now())
            );
        }
    }

    @Transactional
    public CampusMembership createMembership(UUID userId, CreateMembershipRequest req) {
        profileRepository.findByUserId(userId)
                .orElseThrow(() -> BhookException.notFound("Customer profile not found"));
        List<CampusMembership> existing = membershipRepository.findByUserId(userId);
        existing.stream()
                .filter(m -> m.getCampusId().equals(req.campusId()))
                .findAny()
                .ifPresent(m -> {
                    throw BhookException.conflict("Membership for this campus already exists");
                });

        CampusMembership membership = CampusMembership.builder()
                .userId(userId)
                .campusId(req.campusId())
                .membershipType(req.membershipType())
                .verificationStatus(VerificationStatus.PENDING.name())
                .validFrom(Instant.now())
                .isActive(false)
                .build();
        membership = membershipRepository.save(membership);

        outbox.write(
                Topics.CUSTOMER_EVENTS,
                "Membership",
                membership.getId().toString(),
                MembershipCreatedEvent.EVENT_TYPE,
                new MembershipCreatedEvent(membership.getId(), userId, membership.getCampusId(),
                        membership.getMembershipType(), Instant.now())
        );
        return membership;
    }

    @Transactional
    public VerificationResponse submitVerification(UUID userId, UUID membershipId, SubmitVerificationRequest req, String bearerToken) {
        CampusMembership membership = membershipRepository.findById(membershipId)
                .orElseThrow(() -> BhookException.notFound("Membership not found"));
        if (!membership.getUserId().equals(userId)) {
            throw BhookException.forbidden("Membership does not belong to this user");
        }

        CampusDomainLookup lookup = campusClient.lookupByEmail(req.submittedEmail(), bearerToken);
        CampusDomainLookup.Match match = lookup.matches().stream()
                .filter(m -> m.campusId().equals(membership.getCampusId()))
                .findFirst()
                .orElse(null);

        VerificationStatus resolvedStatus;
        boolean autoVerified;
        if (match == null) {
            resolvedStatus = VerificationStatus.MANUAL_REQUIRED;
            autoVerified = false;
        } else if (match.autoVerify()) {
            resolvedStatus = VerificationStatus.AUTO_VERIFIED;
            autoVerified = true;
        } else {
            resolvedStatus = VerificationStatus.PENDING_REVIEW;
            autoVerified = false;
        }

        MembershipVerification verification = MembershipVerification.builder()
                .membershipId(membership.getId())
                .userId(userId)
                .campusId(membership.getCampusId())
                .submittedEmail(req.submittedEmail())
                .evidenceObjectKeys(req.evidenceObjectKeys() == null ? List.of() : req.evidenceObjectKeys())
                .domainMatch(match != null ? lookup.domain() : null)
                .matchedMembership(match != null ? match.membershipType() : null)
                .autoVerified(autoVerified)
                .status(resolvedStatus)
                .build();
        verification = verificationRepository.save(verification);

        membership.setVerificationStatus(resolvedStatus.name());
        membership.setVerificationMethod(match != null ? "EMAIL_DOMAIN" : "MANUAL_REVIEW");
        if (autoVerified) {
            membership.setActive(true);
            outbox.write(
                    Topics.CUSTOMER_EVENTS,
                    "Membership",
                    membership.getId().toString(),
                    MembershipVerifiedEvent.EVENT_TYPE,
                    new MembershipVerifiedEvent(membership.getId(), verification.getId(), userId,
                            membership.getCampusId(), match.membershipType(), true, Instant.now())
            );
        } else {
            outbox.write(
                    Topics.CUSTOMER_EVENTS,
                    "Verification",
                    verification.getId().toString(),
                    VerificationReviewRequestedEvent.EVENT_TYPE,
                    new VerificationReviewRequestedEvent(verification.getId(), membership.getId(), userId,
                            membership.getCampusId(), req.submittedEmail(),
                            match == null ? "NO_DOMAIN_MATCH" : "REVIEW_REQUIRED", Instant.now())
            );
        }
        membershipRepository.save(membership);

        return toResponse(verification);
    }

    @Transactional
    public VerificationResponse adminReview(UUID verificationId, boolean approve, UUID reviewerId, String notes) {
        MembershipVerification v = verificationRepository.findById(verificationId)
                .orElseThrow(() -> BhookException.notFound("Verification not found"));
        if (v.getStatus() == VerificationStatus.APPROVED || v.getStatus() == VerificationStatus.REJECTED) {
            throw BhookException.conflict("Verification already decided");
        }
        CampusMembership membership = membershipRepository.findById(v.getMembershipId())
                .orElseThrow(() -> BhookException.notFound("Membership not found"));

        VerificationStatus newStatus = approve ? VerificationStatus.APPROVED : VerificationStatus.REJECTED;
        v.setStatus(newStatus);
        v.setReviewedBy(reviewerId);
        v.setReviewedAt(Instant.now());
        v.setReviewNotes(notes);
        verificationRepository.save(v);

        membership.setVerificationStatus(newStatus.name());
        membership.setActive(approve);
        membershipRepository.save(membership);

        if (approve) {
            outbox.write(
                    Topics.CUSTOMER_EVENTS,
                    "Membership",
                    membership.getId().toString(),
                    MembershipVerifiedEvent.EVENT_TYPE,
                    new MembershipVerifiedEvent(membership.getId(), v.getId(), membership.getUserId(),
                            membership.getCampusId(), v.getMatchedMembership() != null ? v.getMatchedMembership() : membership.getMembershipType(),
                            false, Instant.now())
            );
        }
        return toResponse(v);
    }

    public List<VerificationResponse> forMembership(UUID membershipId) {
        return verificationRepository.findByMembershipIdOrderByCreatedAtDesc(membershipId)
                .stream().map(this::toResponse).toList();
    }

    private VerificationResponse toResponse(MembershipVerification v) {
        return new VerificationResponse(
                v.getId(),
                v.getMembershipId(),
                v.getCampusId(),
                v.getSubmittedEmail(),
                v.getDomainMatch(),
                v.getMatchedMembership(),
                v.isAutoVerified(),
                v.getStatus(),
                v.getCreatedAt()
        );
    }

}
