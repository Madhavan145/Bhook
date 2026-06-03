package com.bhook.catalog.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "catalog_availability", schema = "catalog")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CatalogAvailability {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "item_id", nullable = false, unique = true)
    private UUID itemId;

    @Column(name = "is_available", nullable = false)
    private boolean available;

    @Column(name = "scheduled_from")
    private Instant scheduledFrom;

    @Column(name = "scheduled_to")
    private Instant scheduledTo;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

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
