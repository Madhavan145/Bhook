package com.bhook.identity.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "user_roles",
        schema = "identity",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "role_name", "campus_id", "vendor_id"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserRole {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_name", nullable = false, length = 64)
    private RoleName roleName;

    @Column(name = "campus_id")
    private UUID campusId;

    @Column(name = "vendor_id")
    private UUID vendorId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
