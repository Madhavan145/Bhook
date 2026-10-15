package com.bhook.delivery.api;

import com.bhook.delivery.domain.DeliveryPartner;
import com.bhook.delivery.domain.PartnerStatus;
import com.bhook.delivery.service.DeliveryService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform/delivery-partners")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
public class PlatformDeliveryController {

    private final DeliveryService deliveryService;

    @GetMapping
    public List<DeliveryPartner> list(@RequestParam(required = false) UUID campusId,
                                      @RequestParam(required = false) PartnerStatus status) {
        return deliveryService.list(campusId, status);
    }

    @PostMapping
    public DeliveryPartner create(@RequestBody CreatePartnerRequest req) {
        return deliveryService.createByPlatform(req.userId(), req.campusId());
    }

    @GetMapping("/summary")
    public DeliveryService.PartnerSummary summary() {
        return deliveryService.summary();
    }

    @PostMapping("/{partnerId}/approve")
    public DeliveryPartner approve(@PathVariable UUID partnerId) {
        return deliveryService.approve(partnerId);
    }

    @PostMapping("/{partnerId}/suspend")
    public DeliveryPartner suspend(@PathVariable UUID partnerId) {
        return deliveryService.setStatus(partnerId, PartnerStatus.SUSPENDED);
    }

    @PostMapping("/{partnerId}/reactivate")
    public DeliveryPartner reactivate(@PathVariable UUID partnerId) {
        return deliveryService.setStatus(partnerId, PartnerStatus.ACTIVE);
    }

    @PostMapping("/{partnerId}/deactivate")
    public DeliveryPartner deactivate(@PathVariable UUID partnerId) {
        return deliveryService.setStatus(partnerId, PartnerStatus.DEACTIVATED);
    }

    public record CreatePartnerRequest(UUID userId, UUID campusId) {}
}