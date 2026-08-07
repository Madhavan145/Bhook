package com.bhook.operations.service;

import com.bhook.common.error.BhookException;
import com.bhook.operations.domain.SupportTicket;
import com.bhook.operations.repository.SupportTicketRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SupportService {

    private final SupportTicketRepository repository;

    @Transactional
    public SupportTicket open(UUID openerId, String category, String subject, String body,
                              UUID relatedOrderId, UUID relatedVendorId) {
        return repository.save(SupportTicket.builder()
                .openerUserId(openerId)
                .category(category)
                .subject(subject)
                .body(body)
                .relatedOrderId(relatedOrderId)
                .relatedVendorId(relatedVendorId)
                .status("OPEN")
                .build());
    }

    @Transactional
    public SupportTicket assign(UUID ticketId, UUID assignee) {
        SupportTicket t = require(ticketId);
        t.setAssignedTo(assignee);
        if ("OPEN".equals(t.getStatus())) t.setStatus("IN_PROGRESS");
        return repository.save(t);
    }

    @Transactional
    public SupportTicket updateStatus(UUID ticketId, String status, String resolutionNotes) {
        SupportTicket t = require(ticketId);
        t.setStatus(status);
        if (resolutionNotes != null) t.setResolutionNotes(resolutionNotes);
        return repository.save(t);
    }

    public List<SupportTicket> mine(UUID openerId) {
        return repository.findByOpenerUserIdOrderByCreatedAtDesc(openerId);
    }

    public List<SupportTicket> byStatus(String status) {
        return repository.findByStatusOrderByCreatedAtAsc(status);
    }

    private SupportTicket require(UUID id) {
        return repository.findById(id).orElseThrow(() -> BhookException.notFound("Ticket not found"));
    }
}
