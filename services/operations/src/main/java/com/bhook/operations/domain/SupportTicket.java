package com.bhook.operations.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "support_tickets", schema = "operations")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SupportTicket {
    @Id @UuidGenerator private UUID id;
    @Column(name = "opener_user_id", nullable = false) private UUID openerUserId;
    @Column(nullable = false, length = 32) private String category;
    @Column(nullable = false, length = 200) private String subject;
    @Column(nullable = false, columnDefinition = "text") private String body;
    @Column(nullable = false, length = 32) private String status;
    @Column(name = "assigned_to") private UUID assignedTo;
    @Column(name = "related_order_id") private UUID relatedOrderId;
    @Column(name = "related_vendor_id") private UUID relatedVendorId;
    @Column(name = "resolution_notes", columnDefinition = "text") private String resolutionNotes;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    @PrePersist void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now; this.updatedAt = now;
        if (this.status == null) this.status = "OPEN";
    }
    @PreUpdate void onUpdate() { this.updatedAt = Instant.now(); }
}
