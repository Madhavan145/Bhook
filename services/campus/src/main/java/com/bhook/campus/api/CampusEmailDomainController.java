package com.bhook.campus.api;

import com.bhook.campus.api.dto.DomainLookupResponse;
import com.bhook.campus.api.dto.EmailDomainRequest;
import com.bhook.campus.api.dto.EmailDomainResponse;
import com.bhook.campus.service.CampusEmailDomainService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/campuses")
@RequiredArgsConstructor
@Validated
public class CampusEmailDomainController {

    private final CampusEmailDomainService service;

    @PostMapping("/{campusId}/email-domains")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public ResponseEntity<EmailDomainResponse> add(@PathVariable UUID campusId, @Valid @RequestBody EmailDomainRequest req) {
        return ResponseEntity.status(201).body(service.addDomain(campusId, req));
    }

    @GetMapping("/{campusId}/email-domains")
    @PreAuthorize("isAuthenticated()")
    public List<EmailDomainResponse> list(@PathVariable UUID campusId) {
        return service.listForCampus(campusId);
    }

    @DeleteMapping("/{campusId}/email-domains/{domainId}")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS')")
    public ResponseEntity<Void> archive(@PathVariable UUID campusId, @PathVariable UUID domainId) {
        service.archive(campusId, domainId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/email-domains/lookup")
    public DomainLookupResponse lookup(@RequestParam @NotBlank @Email String email) {
        return service.lookupByEmail(email);
    }
}
