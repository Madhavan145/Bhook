package com.bhook.delivery.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "delivery_jobs", schema = "delivery")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeliveryJob {

    @Id @UuidGenerator private UUID id;

    @Column(name = "order_id", nullable = false, unique = true)
    private UUID orderId;

    @Column(name = "vendor_id", nullable = false)
    private UUID vendorId;

    @Column(name = "campus_id", nullable = false)
    private UUID campusId;

    @Column(name = "partner_id")
    private UUID partnerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private JobStatus status;

    @Column(name = "assigned_at") private Instant assignedAt;
    @Column(name = "accepted_at") private Instant acceptedAt;
    @Column(name = "pickup_at") private Instant pickupAt;
    @Column(name = "delivered_at") private Instant deliveredAt;

    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
