package com.bhook.catalog.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "catalog_items", schema = "catalog")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CatalogItem {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "vendor_id", nullable = false)
    private UUID vendorId;

    @Column(name = "category_id", nullable = false)
    private UUID categoryId;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "price_minor", nullable = false)
    private long priceMinor;

    @Column(name = "offer_price_minor")
    private Long offerPriceMinor;

    @Column(name = "offer_ends_at")
    private Instant offerEndsAt;

    @Column(name = "tax_minor", nullable = false)
    private long taxMinor;

    @Column(name = "prep_time_minutes")
    private Integer prepTimeMinutes;

    @Column(name = "image_object_key", length = 512)
    private String imageObjectKey;

    @Column(name = "dietary_tags", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private List<String> dietaryTags;

    @Column(nullable = false, length = 32)
    private String status;

    @Column(name = "is_archived", nullable = false)
    private boolean archived;

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
        if (this.status == null) this.status = "ACTIVE";
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
