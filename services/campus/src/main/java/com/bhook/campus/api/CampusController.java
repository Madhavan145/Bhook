package com.bhook.campus.api;

import com.bhook.campus.api.dto.CreateCampusRequest;
import com.bhook.campus.api.dto.CreateLocationRequest;
import com.bhook.campus.api.dto.UpdateCampusRequest;
import com.bhook.campus.api.dto.UpdateLocationRequest;
import com.bhook.campus.domain.Campus;
import com.bhook.campus.domain.CampusLocation;
import com.bhook.campus.domain.CampusStatus;
import com.bhook.campus.repository.CampusLocationRepository;
import com.bhook.campus.repository.CampusRepository;
import com.bhook.campus.service.CampusEmailDomainService;
import com.bhook.common.error.BhookException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/campuses")
@RequiredArgsConstructor
public class CampusController {

    private final CampusRepository campusRepository;
    private final CampusLocationRepository locationRepository;
    private final CampusEmailDomainService emailDomainService;

    @GetMapping
    public List<Campus> list() {
        return campusRepository.findByStatus(CampusStatus.ACTIVE);
    }

    @GetMapping("/{campusId}")
    public Campus get(@PathVariable UUID campusId) {
        return campusRepository.findById(campusId)
                .orElseThrow(() -> BhookException.notFound("Campus not found"));
    }

    @PatchMapping("/{campusId}")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public Campus update(@PathVariable UUID campusId, @Valid @RequestBody UpdateCampusRequest req) {
        Campus campus = campusRepository.findById(campusId)
                .orElseThrow(() -> BhookException.notFound("Campus not found"));
        if (req.name() != null) campus.setName(req.name());
        if (req.displayName() != null) campus.setDisplayName(req.displayName());
        if (req.country() != null) campus.setCountry(req.country());
        if (req.region() != null) campus.setRegion(req.region());
        if (req.timezone() != null) campus.setTimezone(req.timezone());
        if (req.currency() != null) campus.setCurrency(req.currency());
        if (req.latitude() != null) campus.setLatitude(req.latitude());
        if (req.longitude() != null) campus.setLongitude(req.longitude());
        if (req.status() != null) campus.setStatus(req.status());
        if (req.deliveryEnabled() != null) campus.setDeliveryEnabled(req.deliveryEnabled());
        if (req.hostelPickupEnabled() != null) campus.setHostelPickupEnabled(req.hostelPickupEnabled());
        if (req.partnerAccessEnabled() != null) campus.setPartnerAccessEnabled(req.partnerAccessEnabled());
        if (req.platformFeeMinor() != null) campus.setPlatformFeeMinor(req.platformFeeMinor());
        return campusRepository.save(campus);
    }

    @GetMapping("/{campusId}/locations")
    public List<CampusLocation> locations(@PathVariable UUID campusId) {
        return locationRepository.findByCampusId(campusId);
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public ResponseEntity<Campus> create(@Valid @RequestBody CreateCampusRequest req) {
        Campus campus = Campus.builder()
                .name(req.name())
                .displayName(req.displayName())
                .country(req.country())
                .region(req.region())
                .timezone(req.timezone())
                .currency(req.currency())
                .latitude(req.latitude())
                .longitude(req.longitude())
                .status(req.status())
                .deliveryEnabled(req.deliveryEnabled())
                .hostelPickupEnabled(req.hostelPickupEnabled())
                .partnerAccessEnabled(req.partnerAccessEnabled())
                .platformFeeMinor(req.platformFeeMinor() == null ? 1000L : req.platformFeeMinor())
                .build();
        campus = campusRepository.save(campus);
        emailDomainService.addDomains(campus.getId(), req.emailDomains());
        return ResponseEntity.status(201).body(campus);
    }

    @PostMapping("/{campusId}/locations")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public ResponseEntity<CampusLocation> addLocation(@PathVariable UUID campusId, @Valid @RequestBody CreateLocationRequest req) {
        campusRepository.findById(campusId)
                .orElseThrow(() -> BhookException.notFound("Campus not found"));
        CampusLocation location = CampusLocation.builder()
                .campusId(campusId)
                .name(req.name())
                .locationType(req.locationType())
                .parentId(req.parentId())
                .latitude(req.latitude())
                .longitude(req.longitude())
                .instructions(req.instructions())
                .status("ACTIVE")
                .build();
        location = locationRepository.save(location);
        return ResponseEntity.status(201).body(location);
    }

    @PatchMapping("/{campusId}/locations/{locationId}")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public CampusLocation updateLocation(@PathVariable UUID campusId, @PathVariable UUID locationId,
                                         @RequestBody UpdateLocationRequest req) {
        CampusLocation location = locationRepository.findById(locationId)
                .filter(item -> item.getCampusId().equals(campusId))
                .orElseThrow(() -> BhookException.notFound("Campus location not found"));
        if (req.name() != null) location.setName(req.name());
        if (req.locationType() != null) location.setLocationType(req.locationType());
        if (req.parentId() != null) location.setParentId(req.parentId());
        if (req.latitude() != null) location.setLatitude(req.latitude());
        if (req.longitude() != null) location.setLongitude(req.longitude());
        if (req.instructions() != null) location.setInstructions(req.instructions());
        if (req.status() != null) location.setStatus(req.status());
        return locationRepository.save(location);
    }

    @DeleteMapping("/{campusId}/locations/{locationId}")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public ResponseEntity<Void> deleteLocation(@PathVariable UUID campusId, @PathVariable UUID locationId) {
        CampusLocation location = locationRepository.findById(locationId)
                .filter(item -> item.getCampusId().equals(campusId))
                .orElseThrow(() -> BhookException.notFound("Campus location not found"));
        locationRepository.delete(location);
        return ResponseEntity.noContent().build();
    }
}
