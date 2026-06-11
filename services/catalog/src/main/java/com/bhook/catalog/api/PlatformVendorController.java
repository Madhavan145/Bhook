package com.bhook.catalog.api;

import com.bhook.catalog.api.dto.LifecycleDecisionRequest;
import com.bhook.catalog.api.dto.AdminVendorCreatedResponse;
import com.bhook.catalog.api.dto.CreateVendorAdminRequest;
import com.bhook.catalog.api.dto.VendorResponse;
import com.bhook.catalog.api.dto.UpdateVendorRequest;
import com.bhook.catalog.domain.Vendor;
import com.bhook.catalog.domain.VendorLifecycleStatus;
import com.bhook.catalog.repository.VendorRepository;
import com.bhook.catalog.service.VendorService;
import com.bhook.common.security.AuthContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import com.fasterxml.jackson.databind.ObjectMapper;

@RestController
@RequestMapping("/api/v1/platform/vendors")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
public class PlatformVendorController {

    private final VendorService vendorService;
    private final VendorRepository vendorRepository;
    private final ObjectMapper objectMapper;

    @GetMapping
    public List<VendorResponse> list(@RequestParam(required = false) VendorLifecycleStatus status) {
        List<Vendor> vendors = status == null
                ? vendorRepository.findAll()
                : vendorRepository.findByLifecycleStatus(status);
        return vendors.stream().map(v -> new VendorResponse(
                v.getId(), v.getCampusId(), v.getVendorType(),
                v.getLegalName(), v.getDisplayName(), v.getDescription(),
                v.getContactEmail(), v.getContactPhone(), v.getLifecycleStatus(),
                v.getLogoObjectKey(), v.getCoverObjectKey(), v.isAutoAcceptOrders(), commissionPercent(v),
                v.getVersion(), v.getCreatedAt(), v.getUpdatedAt()
        )).toList();
    }

    private Double commissionPercent(Vendor vendor) {
        if (vendor.getCommissionConfig() == null) return null;
        try {
            return objectMapper.readTree(vendor.getCommissionConfig()).path("basisPoints").asDouble() / 100.0;
        } catch (Exception ignored) {
            return null;
        }
    }

    @PostMapping
    public AdminVendorCreatedResponse create(@Valid @RequestBody CreateVendorAdminRequest req) {
        return vendorService.createByPlatform(AuthContext.requireUserId(), req);
    }

    @PatchMapping("/{vendorId}")
    public VendorResponse update(@PathVariable UUID vendorId, @Valid @RequestBody UpdateVendorRequest req) {
        return vendorService.updateByPlatform(vendorId, req);
    }

    @PostMapping("/{vendorId}/approve")
    public VendorResponse approve(@PathVariable UUID vendorId, @Valid @RequestBody LifecycleDecisionRequest req) {
        return vendorService.platformTransition(vendorId, VendorLifecycleStatus.APPROVED, AuthContext.requireUserId(),
                normalizeReason(req.reason(), "APPROVED_BY_PLATFORM"));
    }

    @PostMapping("/{vendorId}/reject")
    public VendorResponse reject(@PathVariable UUID vendorId, @Valid @RequestBody LifecycleDecisionRequest req) {
        return vendorService.platformTransition(vendorId, VendorLifecycleStatus.REJECTED, AuthContext.requireUserId(),
                normalizeReason(req.reason(), "REJECTED_BY_PLATFORM"));
    }

    @PostMapping("/{vendorId}/suspend")
    public VendorResponse suspend(@PathVariable UUID vendorId, @Valid @RequestBody LifecycleDecisionRequest req) {
        return vendorService.platformTransition(vendorId, VendorLifecycleStatus.SUSPENDED, AuthContext.requireUserId(),
                normalizeReason(req.reason(), "SUSPENDED_BY_PLATFORM"));
    }

    @PostMapping("/{vendorId}/reactivate")
    public VendorResponse reactivate(@PathVariable UUID vendorId, @Valid @RequestBody LifecycleDecisionRequest req) {
        return vendorService.platformTransition(vendorId, VendorLifecycleStatus.APPROVED, AuthContext.requireUserId(),
                normalizeReason(req.reason(), "REACTIVATED_BY_PLATFORM"));
    }

    private String normalizeReason(String reason, String fallback) {
        return (reason == null || reason.isBlank()) ? fallback : reason;
    }
}
