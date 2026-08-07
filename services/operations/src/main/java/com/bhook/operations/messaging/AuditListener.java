package com.bhook.operations.messaging;

import com.bhook.common.events.Topics;
import com.bhook.operations.domain.AuditEntry;
import com.bhook.operations.repository.AuditEntryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Header;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class AuditListener {

    private final ObjectMapper objectMapper;
    private final AuditEntryRepository repository;

    @KafkaListener(
            topics = {
                    Topics.IDENTITY_USER_EVENTS,
                    Topics.CUSTOMER_EVENTS,
                    Topics.CAMPUS_EVENTS,
                    Topics.ORDER_EVENTS,
                    Topics.PAYMENT_EVENTS,
                    Topics.DELIVERY_EVENTS
            },
            groupId = "bhook-operations"
    )
    @Transactional
    public void onEvent(ConsumerRecord<String, String> record) {
        String type = header(record, "event-type");
        String aggregateType = header(record, "aggregate-type");
        if (type.isEmpty()) {
            log.debug("Skipping record without event-type on topic {}", record.topic());
            return;
        }
        UUID actorUserId = extractActor(record.value());
        repository.save(AuditEntry.builder()
                .eventType(type)
                .aggregateType(aggregateType.isEmpty() ? "Unknown" : aggregateType)
                .aggregateId(record.key() == null ? "unknown" : record.key())
                .actorUserId(actorUserId)
                .actorType(guessActorType(type))
                .payload(record.value())
                .topic(record.topic())
                .build());
    }

    private UUID extractActor(String payload) {
        try {
            JsonNode n = objectMapper.readTree(payload);
            JsonNode candidate = firstNonNull(n, "actorUserId", "userId", "openerUserId", "reviewerId");
            if (candidate != null && !candidate.isNull()) return UUID.fromString(candidate.asText());
        } catch (Exception ignored) { }
        return null;
    }

    private JsonNode firstNonNull(JsonNode n, String... fields) {
        for (String f : fields) {
            JsonNode v = n.get(f);
            if (v != null && !v.isNull()) return v;
        }
        return null;
    }

    private String guessActorType(String eventType) {
        if (eventType.startsWith("identity.")) return "USER";
        if (eventType.startsWith("customer.")) return "USER";
        if (eventType.startsWith("catalog.vendor.")) return "VENDOR";
        if (eventType.startsWith("order.")) return "USER";
        if (eventType.startsWith("payment.")) return "PAYMENT_SERVICE";
        if (eventType.startsWith("delivery.")) return "DELIVERY";
        return "SYSTEM";
    }

    private String header(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
