package com.bhook.customer.api;

import com.bhook.common.security.AuthContext;
import com.bhook.customer.api.dto.CreateMembershipRequest;
import com.bhook.customer.api.dto.SubmitVerificationRequest;
import com.bhook.customer.api.dto.VerificationResponse;
import com.bhook.customer.api.dto.CustomerDirectoryEntry;
import com.bhook.customer.api.dto.UpdateCustomerProfileRequest;
import com.bhook.customer.domain.CampusMembership;
import com.bhook.customer.domain.CustomerProfile;
import com.bhook.customer.repository.CampusMembershipRepository;
import com.bhook.customer.service.CustomerProfileService;
import com.bhook.customer.service.VerificationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customers")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerController {

    private final CustomerProfileService profileService;
    private final CampusMembershipRepository membershipRepository;
    private final VerificationService verificationService;

    @GetMapping("/me")
    public CustomerProfile me() {
        return profileService.findByUserId(AuthContext.requireUserId());
    }

    @PutMapping("/me/profile")
    public CustomerProfile updateProfile(@Valid @RequestBody UpdateCustomerProfileRequest req) {
        return profileService.updateProfile(AuthContext.requireUserId(), req);
    }

    @GetMapping("/directory/code/{friendCode}")
    public CustomerDirectoryEntry findByFriendCode(@PathVariable String friendCode) {
        return profileService.findByFriendCode(AuthContext.requireUserId(), friendCode);
    }

    @GetMapping("/me/memberships")
    public List<CampusMembership> memberships() {
        return membershipRepository.findByUserId(AuthContext.requireUserId());
    }

    @PostMapping("/me/memberships")
    public CampusMembership createMembership(@Valid @RequestBody CreateMembershipRequest req) {
        return verificationService.createMembership(AuthContext.requireUserId(), req);
    }

    @PostMapping("/me/memberships/{membershipId}/verification")
    public VerificationResponse submitVerification(@PathVariable UUID membershipId,
                                                   @Valid @RequestBody SubmitVerificationRequest req,
                                                   HttpServletRequest http) {
        String bearer = extractBearer(http);
        return verificationService.submitVerification(AuthContext.requireUserId(), membershipId, req, bearer);
    }

    @GetMapping("/me/memberships/{membershipId}/verification")
    public List<VerificationResponse> listVerifications(@PathVariable UUID membershipId) {
        UUID userId = AuthContext.requireUserId();
        CampusMembership membership = membershipRepository.findById(membershipId)
                .orElseThrow(() -> com.bhook.common.error.BhookException.notFound("Membership not found"));
        if (!membership.getUserId().equals(userId)) {
            throw com.bhook.common.error.BhookException.forbidden("Membership does not belong to this user");
        }
        return verificationService.forMembership(membershipId);
    }

    @PutMapping("/me/active-campus")
    public CustomerProfile setActiveCampus(@RequestBody ActiveCampusRequest req) {
        return profileService.setActiveCampus(AuthContext.requireUserId(), req.campusId());
    }

    public record ActiveCampusRequest(@NotNull UUID campusId) {}

    private String extractBearer(HttpServletRequest req) {
        String h = req.getHeader("Authorization");
        return (h != null && h.startsWith("Bearer ")) ? h.substring(7) : "";
    }
}
