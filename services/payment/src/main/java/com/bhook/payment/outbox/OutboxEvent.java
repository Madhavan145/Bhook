package com.bhook.payment.outbox;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "outbox_events", schema = "payment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OutboxEvent {
    @Id @UuidGenerator private UUID id;
    @Column(name = "aggregate_type", nullable = false, length = 64) private String aggregateType;
    @Column(name = "aggregate_id", nullable = false, length = 64) private String aggregateId;
    @Column(name = "event_type", nullable = false, length = 128) private String eventType;
    @Column(name = "payload", nullable = false, columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String payload;
    @Column(name = "topic", nullable = false, length = 128) private String topic;
    @Column(name = "published_at") private Instant publishedAt;
    @Column(name = "attempts", nullable = false) private int attempts;
    @Column(name = "last_error", columnDefinition = "text") private String lastError;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    @PrePersist void onCreate() { this.createdAt = Instant.now(); }
}
