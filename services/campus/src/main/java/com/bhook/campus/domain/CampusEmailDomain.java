package com.bhook.campus.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "campus_email_domains",
        schema = "campus",
        uniqueConstraints = @UniqueConstraint(columnNames = {"campus_id", "domain"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CampusEmailDomain {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "campus_id", nullable = false)
    private UUID campusId;

    @Column(nullable = false, length = 255)
    private String domain;

    @Enumerated(EnumType.STRING)
    @Column(name = "membership_type", nullable = false, length = 32)
    private MembershipType membershipType;

    @Column(name = "auto_verify", nullable = false)
    private boolean autoVerify;

    @Column(nullable = false, length = 32)
    private String status;

    @Column(name = "notes", length = 512)
    private String notes;

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
        if (this.domain != null) this.domain = this.domain.toLowerCase();
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
        if (this.domain != null) this.domain = this.domain.toLowerCase();
    }
}
