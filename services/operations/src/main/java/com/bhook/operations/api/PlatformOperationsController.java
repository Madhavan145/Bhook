package com.bhook.operations.api;

import com.bhook.common.security.AuthContext;
import com.bhook.operations.domain.AuditEntry;
import com.bhook.operations.domain.SupportTicket;
import com.bhook.operations.repository.AuditEntryRepository;
import com.bhook.operations.service.SupportService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS','PLATFORM_SUPPORT')")
public class PlatformOperationsController {

    private final AuditEntryRepository auditRepository;
    private final SupportService support;

    @GetMapping("/audit-log")
    public Page<AuditEntry> audit(@RequestParam(defaultValue = "0") int page,
                                  @RequestParam(defaultValue = "50") int size,
                                  @RequestParam(required = false) String eventType,
                                  @RequestParam(required = false) String aggregateType,
                                  @RequestParam(required = false) String aggregateId) {
        var pageable = PageRequest.of(page, Math.min(size, 200), Sort.by(Sort.Direction.DESC, "createdAt"));
        if (aggregateType != null && aggregateId != null) {
            return auditRepository.findByAggregateTypeAndAggregateId(aggregateType, aggregateId, pageable);
        }
        if (eventType != null) {
            return auditRepository.findByEventType(eventType, pageable);
        }
        return auditRepository.findAll(pageable);
    }

    @GetMapping("/support/tickets")
    public List<SupportTicket> tickets(@RequestParam(defaultValue = "OPEN") String status) {
        return support.byStatus(status);
    }

    @PostMapping("/support/tickets")
    public ResponseEntity<SupportTicket> open(@Valid @RequestBody OpenRequest req) {
        return ResponseEntity.status(201).body(support.open(
                AuthContext.requireUserId(), req.category(), req.subject(), req.body(),
                req.relatedOrderId(), req.relatedVendorId()));
    }

    @PostMapping("/support/tickets/{ticketId}/assign")
    public SupportTicket assign(@PathVariable UUID ticketId) {
        return support.assign(ticketId, AuthContext.requireUserId());
    }

    @PatchMapping("/support/tickets/{ticketId}/status")
    public SupportTicket updateStatus(@PathVariable UUID ticketId, @RequestBody StatusUpdate req) {
        return support.updateStatus(ticketId, req.status(), req.resolutionNotes());
    }

    public record StatusUpdate(String status, String resolutionNotes) {}

    public record OpenRequest(@NotBlank String category, @NotBlank String subject,
                              @NotBlank String body, UUID relatedOrderId, UUID relatedVendorId) {}
}
