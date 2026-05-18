package com.bhook.identity.outbox;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.header.internals.RecordHeader;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.domain.PageRequest;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;

@Slf4j
@Component
@ConditionalOnProperty(prefix = "bhook.outbox", name = "enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class OutboxPublisher {

    private final OutboxEventRepository repository;
    private final KafkaTemplate<String, String> kafkaTemplate;

    @Scheduled(fixedDelayString = "${bhook.outbox.poll-ms:2000}")
    @Transactional
    public void publishPending() {
        List<OutboxEvent> batch = repository.findUnpublished(PageRequest.of(0, 50));
        for (OutboxEvent event : batch) {
            try {
                ProducerRecord<String, String> record = new ProducerRecord<>(
                        event.getTopic(), null, null, event.getAggregateId(), event.getPayload());
                record.headers().add(new RecordHeader("event-type", event.getEventType().getBytes(StandardCharsets.UTF_8)));
                record.headers().add(new RecordHeader("aggregate-type", event.getAggregateType().getBytes(StandardCharsets.UTF_8)));
                kafkaTemplate.send(record).get();
                event.setPublishedAt(Instant.now());
                event.setLastError(null);
            } catch (Exception e) {
                event.setAttempts(event.getAttempts() + 1);
                event.setLastError(truncate(e.getMessage(), 500));
                if (event.getAttempts() >= 10) {
                    log.error("DEAD_LETTER outbox event id={} type={} aggregate={}/{} err={}",
                            event.getId(), event.getEventType(), event.getAggregateType(), event.getAggregateId(), e.toString());
                } else {
                    log.warn("Outbox publish failed id={} attempt={} err={}", event.getId(), event.getAttempts(), e.toString());
                }
            }
            repository.save(event);
        }
    }

    private String truncate(String s, int max) {
        if (s == null) return null;
        return s.length() <= max ? s : s.substring(0, max);
    }
}
