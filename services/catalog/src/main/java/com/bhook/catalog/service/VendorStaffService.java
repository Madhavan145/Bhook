package com.bhook.catalog.service;

import com.bhook.catalog.api.dto.AddStaffRequest;
import com.bhook.catalog.domain.Vendor;
import com.bhook.catalog.domain.VendorMembership;
import com.bhook.catalog.domain.VendorRole;
import com.bhook.catalog.repository.VendorMembershipRepository;
import com.bhook.common.error.BhookException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class VendorStaffService {

    private final VendorAccess access;
    private final VendorMembershipRepository membershipRepository;

    @Transactional
    public VendorMembership addStaff(UUID vendorId, UUID actorUserId, AddStaffRequest req) {
        access.requireOwner(vendorId, actorUserId);
        Vendor vendor = access.requireVendor(vendorId);
        if (req.role() == VendorRole.VENDOR_OWNER) {
            throw BhookException.validation("Additional owners must be added by platform ops");
        }
        membershipRepository.findByVendorIdAndUserId(vendorId, req.userId()).ifPresent(m -> {
            throw BhookException.conflict("User is already a member of this vendor");
        });
        return membershipRepository.save(VendorMembership.builder()
                .vendorId(vendor.getId())
                .userId(req.userId())
                .campusId(vendor.getCampusId())
                .role(req.role())
                .status("ACTIVE")
                .build());
    }

    public List<VendorMembership> list(UUID vendorId, UUID actorUserId) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        return membershipRepository.findByVendorId(vendorId);
    }

    @Transactional
    public void remove(UUID vendorId, UUID actorUserId, UUID targetUserId) {
        access.requireOwner(vendorId, actorUserId);
        VendorMembership m = membershipRepository.findByVendorIdAndUserId(vendorId, targetUserId)
                .orElseThrow(() -> BhookException.notFound("Membership not found"));
        if (m.getRole() == VendorRole.VENDOR_OWNER) {
            throw BhookException.forbidden("Cannot remove the vendor owner");
        }
        membershipRepository.delete(m);
    }
}
