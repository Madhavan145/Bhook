package com.bhook.financial.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "order_totals", schema = "financial")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class OrderTotals {

    @Id
    @Column(name = "order_id")
    private UUID orderId;

    @Column(name = "vendor_id", nullable = false) private UUID vendorId;
    @Column(name = "campus_id", nullable = false) private UUID campusId;
    @Column(name = "user_id", nullable = false) private UUID userId;
    @Column(nullable = false, length = 8) private String currency;
    @Column(name = "total_minor", nullable = false) private long totalMinor;
    @Column(name = "subtotal_minor") private Long subtotalMinor;
    @Column(name = "tax_minor") private Long taxMinor;
    @Column(name = "delivery_fee_minor") private Long deliveryFeeMinor;
    @Column(name = "platform_fee_minor") private Long platformFeeMinor;
    @Column(name = "completed_at") private Instant completedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "commission_bps", nullable = false) private int commissionBps;

    @PrePersist void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now; this.updatedAt = now;
    }
    @PreUpdate void onUpdate() { this.updatedAt = Instant.now(); }
}
