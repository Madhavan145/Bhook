package com.bhook.customer.api;

import com.bhook.common.security.AuthContext;
import com.bhook.customer.api.dto.VerificationResponse;
import com.bhook.customer.domain.MembershipVerification;
import com.bhook.customer.domain.VerificationStatus;
import com.bhook.customer.repository.MembershipVerificationRepository;
import com.bhook.customer.service.VerificationService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform/verifications")
@RequiredArgsConstructor
public class PlatformVerificationController {

    private final VerificationService verificationService;
    private final MembershipVerificationRepository repository;

    @GetMapping
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS','PLATFORM_SUPPORT')")
    public List<VerificationResponse> list(@RequestParam(defaultValue = "PENDING_REVIEW") VerificationStatus status) {
        return repository.findByStatusOrderByCreatedAtAsc(status).stream()
                .map(this::toResponse)
                .toList();
    }

    @PostMapping("/{verificationId}/decision")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS','PLATFORM_SUPPORT')")
    public VerificationResponse decide(@PathVariable UUID verificationId, @Valid @RequestBody DecisionRequest req) {
        return verificationService.adminReview(verificationId, req.approve(), AuthContext.requireUserId(), req.notes());
    }

    public record DecisionRequest(boolean approve, @Size(max = 2000) String notes) {}

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
