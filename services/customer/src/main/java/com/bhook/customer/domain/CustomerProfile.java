package com.bhook.customer.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "customer_profiles", schema = "customer")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CustomerProfile {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "friend_code", nullable = false, unique = true, length = 36)
    private String friendCode;

    @Column(length = 255)
    private String email;

    @Column(name = "phone_e164", length = 32)
    private String phoneE164;

    @Column(name = "display_name", length = 120)
    private String displayName;

    @Column(columnDefinition = "text")
    private String bio;

    @Column(name = "profile_image_url", length = 512)
    private String profileImageUrl;

    @Column(name = "profile_image_object_key", length = 512)
    private String profileImageObjectKey;

    @Column(name = "active_campus_id")
    private UUID activeCampusId;

    @Column(name = "verification_state", nullable = false, length = 32)
    private String verificationState;

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
        if (this.verificationState == null) this.verificationState = "PENDING";
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
