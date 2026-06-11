package com.bhook.catalog.api;

import com.bhook.catalog.api.dto.CreateVendorApplicationRequest;
import com.bhook.catalog.api.dto.UpdateVendorRequest;
import com.bhook.catalog.api.dto.VendorResponse;
import com.bhook.catalog.service.VendorService;
import com.bhook.common.security.AuthContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendors")
@RequiredArgsConstructor
public class VendorController {

    private final VendorService vendorService;

    @PostMapping("/apply")
    public ResponseEntity<VendorResponse> apply(@Valid @RequestBody CreateVendorApplicationRequest req) {
        return ResponseEntity.status(201).body(vendorService.apply(AuthContext.requireUserId(), req));
    }

    @GetMapping("/me")
    public List<VendorResponse> mine() {
        return vendorService.myVendors(AuthContext.requireUserId());
    }

    @PostMapping("/invitations/{token}/accept")
    public ResponseEntity<Void> acceptInvitation(@PathVariable String token) {
        vendorService.acceptInvitation(AuthContext.requireUserId(), token);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{vendorId}/manage")
    public VendorResponse getForManage(@PathVariable UUID vendorId) {
        return vendorService.get(vendorId);
    }

    @PatchMapping("/{vendorId}")
    public VendorResponse update(@PathVariable UUID vendorId, @Valid @RequestBody UpdateVendorRequest req) {
        return vendorService.update(vendorId, AuthContext.requireUserId(), req);
    }

    @PostMapping("/{vendorId}/activate")
    public VendorResponse activate(@PathVariable UUID vendorId) {
        return vendorService.activateAfterApproval(vendorId, AuthContext.requireUserId());
    }

    @PostMapping("/{vendorId}/pause")
    public VendorResponse pause(@PathVariable UUID vendorId, @RequestBody PauseRequest req) {
        return vendorService.pause(vendorId, AuthContext.requireUserId(), req.reason());
    }

    public record PauseRequest(String reason) {}
}
