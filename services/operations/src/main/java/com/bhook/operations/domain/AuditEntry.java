package com.bhook.operations.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "audit_log", schema = "operations")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AuditEntry {
    @Id @UuidGenerator private UUID id;
    @Column(name = "event_type", nullable = false, length = 128) private String eventType;
    @Column(name = "aggregate_type", nullable = false, length = 64) private String aggregateType;
    @Column(name = "aggregate_id", nullable = false, length = 64) private String aggregateId;
    @Column(name = "actor_user_id") private UUID actorUserId;
    @Column(name = "actor_type", length = 32) private String actorType;
    @Column(nullable = false, columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String payload;
    @Column(nullable = false, length = 128) private String topic;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    @PrePersist void onCreate() { this.createdAt = Instant.now(); }
}
