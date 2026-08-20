package com.bhook.operations.api;

import com.bhook.common.security.AuthContext;
import com.bhook.operations.domain.SupportTicket;
import com.bhook.operations.service.SupportService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/support/tickets")
@RequiredArgsConstructor
public class SupportTicketController {

    private final SupportService support;

    @PostMapping
    public ResponseEntity<SupportTicket> open(@RequestBody OpenRequest req) {
        return ResponseEntity.status(201).body(support.open(
                AuthContext.requireUserId(),
                req.category(),
                req.subject(),
                req.body(),
                req.relatedOrderId(),
                req.relatedVendorId()
        ));
    }

    @GetMapping
    public List<SupportTicket> mine() {
        return support.mine(AuthContext.requireUserId());
    }

    public record OpenRequest(
            @NotBlank @Size(max = 32) String category,
            @NotBlank @Size(max = 200) String subject,
            @NotBlank @Size(max = 4000) String body,
            UUID relatedOrderId,
            UUID relatedVendorId
    ) {}
}
