package com.bhook.notification.messaging;

import com.bhook.common.events.OrderCreatedEvent;
import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.PaymentSucceededEvent;
import com.bhook.common.events.Topics;
import com.bhook.notification.domain.Notification;
import com.bhook.notification.repository.NotificationRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Header;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
public class DomainEventsListener {

    private final ObjectMapper objectMapper;
    private final NotificationRepository repository;

    @KafkaListener(topics = {Topics.ORDER_EVENTS, Topics.PAYMENT_EVENTS, Topics.DELIVERY_EVENTS}, groupId = "bhook-notification")
    @Transactional
    public void onEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            if (OrderCreatedEvent.EVENT_TYPE.equals(type)) {
                OrderCreatedEvent evt = objectMapper.readValue(record.value(), OrderCreatedEvent.class);
                save(evt.userId(), type, "Order", evt.orderId(), record.value());
            } else if (OrderStatusChangedEvent.EVENT_TYPE.equals(type)) {
                OrderStatusChangedEvent evt = objectMapper.readValue(record.value(), OrderStatusChangedEvent.class);
                save(evt.userId(), type, "Order", evt.orderId(), record.value());
            } else if (PaymentSucceededEvent.EVENT_TYPE.equals(type)) {
                PaymentSucceededEvent evt = objectMapper.readValue(record.value(), PaymentSucceededEvent.class);
                save(null, type, "Payment", evt.orderId(), record.value());
            }
            log.debug("Notification event stored type={}", type);
        } catch (Exception e) {
            log.error("Failed to store notification for event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private void save(java.util.UUID userId, String type, String entityType, java.util.UUID entityId, String payload) {
        if (userId == null) return;
        repository.save(Notification.builder()
                .userId(userId).type(type).entityType(entityType).entityId(entityId).payload(payload)
                .build());
    }

    private String headerString(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
