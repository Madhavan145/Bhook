package com.bhook.catalog.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vendors", schema = "catalog")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Vendor {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "campus_id", nullable = false)
    private UUID campusId;

    @Column(name = "vendor_type", nullable = false, length = 32)
    private String vendorType;

    @Column(name = "legal_name", nullable = false, length = 255)
    private String legalName;

    @Column(name = "display_name", nullable = false, length = 255)
    private String displayName;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "contact_email", length = 255)
    private String contactEmail;

    @Column(name = "contact_phone", length = 32)
    private String contactPhone;

    @Enumerated(EnumType.STRING)
    @Column(name = "lifecycle_status", nullable = false, length = 32)
    private VendorLifecycleStatus lifecycleStatus;

    @Column(name = "commission_config", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String commissionConfig;

    @Column(name = "payment_config", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String paymentConfig;

    @Column(name = "operating_hours", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String operatingHours;

    @Column(name = "logo_object_key", length = 512)
    private String logoObjectKey;

    @Column(name = "cover_object_key", length = 512)
    private String coverObjectKey;

    @Column(name = "auto_accept_orders", nullable = false)
    private boolean autoAcceptOrders;

    @Version
    @Column(nullable = false)
    private Integer version;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.vendorType == null) this.vendorType = "FOOD";
        if (this.lifecycleStatus == null) this.lifecycleStatus = VendorLifecycleStatus.APPLICATION;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
