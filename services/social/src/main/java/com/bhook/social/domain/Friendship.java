package com.bhook.social.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "friendships",
        schema = "social",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_a_id", "user_b_id"})
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Friendship {
    @Id @UuidGenerator private UUID id;

    @Column(name = "user_a_id", nullable = false) private UUID userAId;
    @Column(name = "user_b_id", nullable = false) private UUID userBId;
    @Column(name = "requested_by", nullable = false) private UUID requestedBy;
    @Column(name = "campus_id") private UUID campusId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32) private FriendshipStatus status;

    @Column(name = "responded_at") private Instant respondedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    @PrePersist void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now; this.updatedAt = now;
        if (this.status == null) this.status = FriendshipStatus.PENDING;
    }
    @PreUpdate void onUpdate() { this.updatedAt = Instant.now(); }

    public UUID otherUser(UUID me) {
        return userAId.equals(me) ? userBId : userAId;
    }
}
