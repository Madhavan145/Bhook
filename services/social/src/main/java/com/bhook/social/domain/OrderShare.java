package com.bhook.social.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "order_shares",
        schema = "social",
        uniqueConstraints = @UniqueConstraint(columnNames = {"order_id", "shared_with_user_id"})
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class OrderShare {
    @Id @UuidGenerator private UUID id;

    @Column(name = "order_id", nullable = false) private UUID orderId;
    @Column(name = "owner_user_id", nullable = false) private UUID ownerUserId;
    @Column(name = "shared_with_user_id", nullable = false) private UUID sharedWithUserId;

    @Column(name = "vendor_id") private UUID vendorId;
    @Column(name = "vendor_name") private String vendorName;
    @Column(name = "item_id") private UUID itemId;
    @Column(name = "item_name") private String itemName;
    @Column(name = "item_image_object_key") private String itemImageObjectKey;
    @Column(name = "category_name") private String categoryName;

    @Column(nullable = false, length = 32) private String status;
    @Column(name = "expires_at") private Instant expiresAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    @PrePersist void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now; this.updatedAt = now;
        if (this.status == null) this.status = "ACTIVE";
    }
    @PreUpdate void onUpdate() { this.updatedAt = Instant.now(); }
}
