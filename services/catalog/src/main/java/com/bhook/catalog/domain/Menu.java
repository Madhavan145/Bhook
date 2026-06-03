package com.bhook.catalog.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "menus", schema = "catalog")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Menu {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "vendor_id", nullable = false)
    private UUID vendorId;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, length = 32)
    private String status;

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
        if (this.status == null) this.status = "ACTIVE";
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
