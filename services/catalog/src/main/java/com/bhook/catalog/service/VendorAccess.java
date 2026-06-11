package com.bhook.catalog.service;

import com.bhook.catalog.domain.Vendor;
import com.bhook.catalog.domain.VendorLifecycleStatus;
import com.bhook.catalog.domain.VendorMembership;
import com.bhook.catalog.domain.VendorRole;
import com.bhook.catalog.repository.VendorMembershipRepository;
import com.bhook.catalog.repository.VendorRepository;
import com.bhook.common.error.BhookException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class VendorAccess {

    private static final Set<VendorRole> OWNER_ONLY   = EnumSet.of(VendorRole.VENDOR_OWNER);
    private static final Set<VendorRole> OWNER_OR_MGR = EnumSet.of(VendorRole.VENDOR_OWNER, VendorRole.VENDOR_MANAGER);
    private static final Set<VendorRole> ANY_STAFF    = EnumSet.allOf(VendorRole.class);

    private final VendorRepository vendorRepository;
    private final VendorMembershipRepository membershipRepository;

    public Vendor requireVendor(UUID vendorId) {
        return vendorRepository.findById(vendorId)
                .orElseThrow(() -> BhookException.notFound("Vendor not found"));
    }

    public VendorMembership requireMembership(UUID vendorId, UUID userId, Set<VendorRole> allowed) {
        VendorMembership m = membershipRepository.findByVendorIdAndUserId(vendorId, userId)
                .orElseThrow(() -> BhookException.forbidden("Not a member of this vendor"));
        if (!"ACTIVE".equals(m.getStatus())) {
            throw BhookException.forbidden("Vendor membership is not active");
        }
        if (!allowed.contains(m.getRole())) {
            throw BhookException.forbidden("Insufficient vendor role");
        }
        return m;
    }

    public VendorMembership requireOwner(UUID vendorId, UUID userId) {
        return requireMembership(vendorId, userId, OWNER_ONLY);
    }

    public VendorMembership requireOwnerOrManager(UUID vendorId, UUID userId) {
        return requireMembership(vendorId, userId, OWNER_OR_MGR);
    }

    public VendorMembership requireAnyStaff(UUID vendorId, UUID userId) {
        return requireMembership(vendorId, userId, ANY_STAFF);
    }

    public void assertOrderable(Vendor vendor) {
        if (vendor.getLifecycleStatus() != VendorLifecycleStatus.ACTIVE) {
            throw BhookException.forbidden("Vendor is not currently active");
        }
    }
}
