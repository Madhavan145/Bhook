package com.bhook.catalog.service;

import com.bhook.catalog.api.dto.CreateVendorApplicationRequest;
import com.bhook.catalog.api.dto.AdminVendorCreatedResponse;
import com.bhook.catalog.api.dto.UpdateVendorRequest;
import com.bhook.catalog.api.dto.VendorResponse;
import com.bhook.catalog.domain.Vendor;
import com.bhook.catalog.domain.VendorInvitation;
import com.bhook.catalog.domain.VendorLifecycleStatus;
import com.bhook.catalog.domain.VendorMembership;
import com.bhook.catalog.domain.VendorRole;
import com.bhook.catalog.outbox.OutboxWriter;
import com.bhook.catalog.repository.VendorMembershipRepository;
import com.bhook.catalog.repository.VendorRepository;
import com.bhook.catalog.repository.VendorInvitationRepository;
import com.bhook.common.error.BhookException;
import com.bhook.common.events.Topics;
import com.bhook.common.events.VendorApplicationSubmittedEvent;
import com.bhook.common.events.VendorLifecycleChangedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class VendorService {

    private final VendorRepository vendorRepository;
    private final VendorMembershipRepository membershipRepository;
    private final VendorAccess access;
    private final OutboxWriter outbox;
    private final VendorInvitationRepository invitationRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public AdminVendorCreatedResponse createByPlatform(UUID actorUserId, com.bhook.catalog.api.dto.CreateVendorAdminRequest req) {
        Vendor vendor = Vendor.builder()
                .campusId(req.campusId())
                .legalName(req.legalName())
                .displayName(req.displayName())
                .description(req.description())
                .contactEmail(req.ownerEmail())
                .contactPhone(req.contactPhone())
                .lifecycleStatus(VendorLifecycleStatus.APPLICATION)
                .autoAcceptOrders(true)
                .build();
        vendor = vendorRepository.save(vendor);

        // Admin provisioned the owner account directly — link membership, no invitation needed.
        if (req.ownerUserId() != null) {
            final UUID vendorId = vendor.getId();
            final UUID campusId = vendor.getCampusId();
            membershipRepository.findByVendorIdAndUserId(vendorId, req.ownerUserId()).orElseGet(() ->
                    membershipRepository.save(VendorMembership.builder()
                            .vendorId(vendorId)
                            .userId(req.ownerUserId())
                            .campusId(campusId)
                            .role(VendorRole.VENDOR_OWNER)
                            .status("ACTIVE")
                            .build()));
            return new AdminVendorCreatedResponse(toResponse(vendor), null, null);
        }

        String rawToken = generateToken();
        Instant expiresAt = Instant.now().plus(7, ChronoUnit.DAYS);
        invitationRepository.save(VendorInvitation.builder()
                .vendorId(vendor.getId())
                .invitedEmail(req.ownerEmail())
                .tokenHash(hashToken(rawToken))
                .expiresAt(expiresAt)
                .createdBy(actorUserId)
                .build());

        return new AdminVendorCreatedResponse(toResponse(vendor), rawToken, expiresAt);
    }

    @Transactional
    public void acceptInvitation(UUID userId, String rawToken) {
        VendorInvitation invitation = invitationRepository.findByTokenHash(hashToken(rawToken))
                .orElseThrow(() -> BhookException.notFound("Vendor invitation not found"));
        Instant now = Instant.now();
        if (invitation.getAcceptedAt() != null || invitation.getRevokedAt() != null || !invitation.getExpiresAt().isAfter(now)) {
            throw BhookException.conflict("Vendor invitation is invalid or expired");
        }

        Vendor vendor = access.requireVendor(invitation.getVendorId());
        membershipRepository.findByVendorIdAndUserId(vendor.getId(), userId).orElseGet(() ->
                membershipRepository.save(VendorMembership.builder()
                        .vendorId(vendor.getId())
                        .userId(userId)
                        .campusId(vendor.getCampusId())
                        .role(VendorRole.VENDOR_OWNER)
                        .status("ACTIVE")
                        .build()));
        invitation.setAcceptedAt(now);
        invitationRepository.save(invitation);
    }

    private String generateToken() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hashToken(String token) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(
                    MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to hash vendor invitation token", ex);
        }
    }

    @Transactional
    public VendorResponse apply(UUID applicantUserId, CreateVendorApplicationRequest req) {
        Vendor vendor = Vendor.builder()
                .campusId(req.campusId())
                .legalName(req.legalName())
                .displayName(req.displayName())
                .description(req.description())
                .contactEmail(req.contactEmail())
                .contactPhone(req.contactPhone())
                .lifecycleStatus(VendorLifecycleStatus.APPLICATION)
                .autoAcceptOrders(true)
                .build();
        vendor = vendorRepository.save(vendor);

        membershipRepository.save(VendorMembership.builder()
                .vendorId(vendor.getId())
                .userId(applicantUserId)
                .campusId(vendor.getCampusId())
                .role(VendorRole.VENDOR_OWNER)
                .status("ACTIVE")
                .build());

        outbox.write(
                Topics.CAMPUS_EVENTS,
                "Vendor",
                vendor.getId().toString(),
                VendorApplicationSubmittedEvent.EVENT_TYPE,
                new VendorApplicationSubmittedEvent(vendor.getId(), applicantUserId, vendor.getCampusId(),
                        vendor.getLegalName(), vendor.getDisplayName(), Instant.now())
        );
        return toResponse(vendor);
    }

    @Transactional
    public VendorResponse update(UUID vendorId, UUID actorUserId, UpdateVendorRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        Vendor vendor = access.requireVendor(vendorId);
        if (req.legalName() != null) vendor.setLegalName(req.legalName());
        if (req.displayName() != null) vendor.setDisplayName(req.displayName());
        if (req.description() != null) vendor.setDescription(req.description());
        if (req.contactEmail() != null) vendor.setContactEmail(req.contactEmail());
        if (req.contactPhone() != null) vendor.setContactPhone(req.contactPhone());
        if (req.operatingHours() != null) vendor.setOperatingHours(blankToNull(req.operatingHours()));
        if (req.logoObjectKey() != null) vendor.setLogoObjectKey(req.logoObjectKey());
        if (req.coverObjectKey() != null) vendor.setCoverObjectKey(req.coverObjectKey());
        if (req.autoAcceptOrders() != null) vendor.setAutoAcceptOrders(req.autoAcceptOrders());
        return toResponse(vendorRepository.save(vendor));
    }

    @Transactional
    public VendorResponse updateByPlatform(UUID vendorId, UpdateVendorRequest req) {
        Vendor vendor = access.requireVendor(vendorId);
        normalizeJsonFields(vendor);
        if (req.legalName() != null) vendor.setLegalName(req.legalName());
        if (req.displayName() != null) vendor.setDisplayName(req.displayName());
        if (req.description() != null) vendor.setDescription(req.description());
        if (req.contactEmail() != null) vendor.setContactEmail(req.contactEmail());
        if (req.contactPhone() != null) vendor.setContactPhone(req.contactPhone());
        if (req.operatingHours() != null) vendor.setOperatingHours(blankToNull(req.operatingHours()));
        if (req.logoObjectKey() != null) vendor.setLogoObjectKey(req.logoObjectKey());
        if (req.coverObjectKey() != null) vendor.setCoverObjectKey(req.coverObjectKey());
        if (req.autoAcceptOrders() != null) vendor.setAutoAcceptOrders(req.autoAcceptOrders());
        if (req.commissionPercent() != null) {
            vendor.setCommissionConfig("{\"basisPoints\":" + Math.round(req.commissionPercent() * 100) + "}");
        }
        return toResponse(vendorRepository.save(vendor));
    }

    @Transactional
    public VendorResponse activateAfterApproval(UUID vendorId, UUID actorUserId) {
        access.requireOwner(vendorId, actorUserId);
        Vendor vendor = access.requireVendor(vendorId);
        if (vendor.getLifecycleStatus() != VendorLifecycleStatus.APPROVED
                && vendor.getLifecycleStatus() != VendorLifecycleStatus.SUSPENDED) {
            throw BhookException.conflict("Vendor cannot be activated from status " + vendor.getLifecycleStatus());
        }
        return transitionLifecycle(vendor, VendorLifecycleStatus.ACTIVE, actorUserId, "OWNER_ACTIVATION");
    }

    @Transactional
    public VendorResponse pause(UUID vendorId, UUID actorUserId, String reason) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        Vendor vendor = access.requireVendor(vendorId);
        if (vendor.getLifecycleStatus() != VendorLifecycleStatus.ACTIVE) {
            throw BhookException.conflict("Only ACTIVE vendors can be paused");
        }
        return transitionLifecycle(vendor, VendorLifecycleStatus.APPROVED, actorUserId, reason);
    }

    @Transactional
    public VendorResponse platformTransition(UUID vendorId, VendorLifecycleStatus target, UUID actorUserId, String reason) {
        Vendor vendor = access.requireVendor(vendorId);
        return transitionLifecycle(vendor, target, actorUserId, reason);
    }

    public List<VendorResponse> myVendors(UUID userId) {
        return membershipRepository.findByUserId(userId).stream()
                .map(m -> vendorRepository.findById(m.getVendorId()).orElse(null))
                .filter(v -> v != null)
                .map(this::toResponse)
                .toList();
    }

    public VendorResponse get(UUID vendorId) {
        return toResponse(access.requireVendor(vendorId));
    }

    private VendorResponse transitionLifecycle(Vendor vendor, VendorLifecycleStatus target, UUID actorUserId, String reason) {
        VendorLifecycleStatus prev = vendor.getLifecycleStatus();
        vendor.setLifecycleStatus(target);
        Vendor saved = vendorRepository.save(vendor);
        outbox.write(
                Topics.CAMPUS_EVENTS,
                "Vendor",
                saved.getId().toString(),
                VendorLifecycleChangedEvent.EVENT_TYPE,
                new VendorLifecycleChangedEvent(saved.getId(), saved.getCampusId(),
                        prev.name(), target.name(), actorUserId, reason, Instant.now())
        );
        return toResponse(saved);
    }

    private VendorResponse toResponse(Vendor v) {
        return new VendorResponse(
                v.getId(), v.getCampusId(), v.getVendorType(),
                v.getLegalName(), v.getDisplayName(), v.getDescription(),
                v.getContactEmail(), v.getContactPhone(), v.getLifecycleStatus(),
                v.getLogoObjectKey(), v.getCoverObjectKey(), v.isAutoAcceptOrders(), commissionPercent(v),
                v.getVersion(), v.getCreatedAt(), v.getUpdatedAt()
        );
    }

    private Double commissionPercent(Vendor vendor) {
        if (vendor.getCommissionConfig() == null) return null;
        try {
            String value = vendor.getCommissionConfig().replaceAll(".*\\\"basisPoints\\\"\\s*:\\s*([0-9.]+).*", "$1");
            return Double.parseDouble(value) / 100.0;
        } catch (Exception ignored) {
            return null;
        }
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }

    private void normalizeJsonFields(Vendor vendor) {
        vendor.setCommissionConfig(blankToNull(vendor.getCommissionConfig()));
        vendor.setPaymentConfig(blankToNull(vendor.getPaymentConfig()));
        vendor.setOperatingHours(blankToNull(vendor.getOperatingHours()));
    }
}
