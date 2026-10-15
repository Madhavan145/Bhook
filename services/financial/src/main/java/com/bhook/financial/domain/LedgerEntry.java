package com.bhook.financial.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "ledger_entries",
        schema = "financial",
        uniqueConstraints = @UniqueConstraint(columnNames = {"order_id", "entry_type"})
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LedgerEntry {
    @Id @UuidGenerator private UUID id;
    @Column(name = "order_id", nullable = false) private UUID orderId;
    @Column(name = "vendor_id") private UUID vendorId;
    @Column(name = "entry_type", nullable = false, length = 64) private String entryType;
    @Column(nullable = false, length = 8) private String currency;
    @Column(name = "amount_minor", nullable = false) private long amountMinor;
    @Column(columnDefinition = "text") private String notes;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    @PrePersist void onCreate() { this.createdAt = Instant.now(); }
}
