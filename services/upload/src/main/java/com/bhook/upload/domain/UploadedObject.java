package com.bhook.upload.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "uploaded_objects", schema = "uploads")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UploadedObject {
    @Id @UuidGenerator private UUID id;
    @Column(name = "user_id", nullable = false) private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 64) private UploadPurpose purpose;

    @Column(name = "object_key", nullable = false, length = 512, unique = true) private String objectKey;
    @Column(nullable = false, length = 128) private String bucket;
    @Column(name = "content_type", nullable = false, length = 128) private String contentType;
    @Column(name = "size_bytes", nullable = false) private long sizeBytes;
    @Column(length = 128) private String sha256;
    @Column(name = "upload_status", nullable = false, length = 32) private String uploadStatus;
    @Column(name = "committed_at") private Instant committedAt;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    @PrePersist void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now; this.updatedAt = now;
        if (this.uploadStatus == null) this.uploadStatus = "PENDING";
    }
    @PreUpdate void onUpdate() { this.updatedAt = Instant.now(); }
}
