package com.bhook.catalog.api;

import com.bhook.catalog.api.dto.AddStaffRequest;
import com.bhook.catalog.domain.VendorMembership;
import com.bhook.catalog.service.VendorStaffService;
import com.bhook.common.security.AuthContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendors/{vendorId}/staff")
@RequiredArgsConstructor
public class VendorStaffController {

    private final VendorStaffService staffService;

    @PostMapping
    public ResponseEntity<VendorMembership> add(@PathVariable UUID vendorId, @Valid @RequestBody AddStaffRequest req) {
        return ResponseEntity.status(201).body(staffService.addStaff(vendorId, AuthContext.requireUserId(), req));
    }

    @GetMapping
    public List<VendorMembership> list(@PathVariable UUID vendorId) {
        return staffService.list(vendorId, AuthContext.requireUserId());
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<Void> remove(@PathVariable UUID vendorId, @PathVariable UUID userId) {
        staffService.remove(vendorId, AuthContext.requireUserId(), userId);
        return ResponseEntity.noContent().build();
    }
}
