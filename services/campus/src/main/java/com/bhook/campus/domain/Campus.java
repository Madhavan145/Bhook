package com.bhook.campus.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "campuses", schema = "campus")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Campus {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(nullable = false, length = 128)
    private String name;

    @Column(name = "display_name", nullable = false, length = 128)
    private String displayName;

    @Column(nullable = false, length = 64)
    private String country;

    @Column(length = 128)
    private String region;

    @Column(nullable = false, length = 64)
    private String timezone;

    @Column(nullable = false, length = 8)
    private String currency;

    @Column(precision = 9, scale = 6)
    private BigDecimal latitude;

    @Column(precision = 9, scale = 6)
    private BigDecimal longitude;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private CampusStatus status;

    @Column(name = "delivery_enabled", nullable = false)
    private boolean deliveryEnabled;

    @Column(name = "hostel_pickup_enabled", nullable = false)
    private boolean hostelPickupEnabled;

    @Column(name = "partner_access_enabled", nullable = false)
    private boolean partnerAccessEnabled;

    @Column(name = "platform_fee_minor", nullable = false)
    private long platformFeeMinor;

    @Version
    @Column(nullable = false)
    private Integer version;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.status == null) this.status = CampusStatus.DRAFT;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
