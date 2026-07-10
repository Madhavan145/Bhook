package com.bhook.delivery.messaging;

import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.bhook.delivery.service.DeliveryService;
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
public class OrderEventsListener {

    private final ObjectMapper objectMapper;
    private final DeliveryService deliveryService;

    @KafkaListener(topics = Topics.ORDER_EVENTS, groupId = "bhook-delivery")
    @Transactional
    public void onOrderEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            if (OrderStatusChangedEvent.EVENT_TYPE.equals(type)) {
                OrderStatusChangedEvent evt = objectMapper.readValue(record.value(), OrderStatusChangedEvent.class);
                if ("READY_FOR_PICKUP".equals(evt.toStatus())) {
                    deliveryService.createAndDispatch(evt.orderId(), evt.vendorId(), evt.campusId());
                }
            } else {
                log.debug("Ignoring order event: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to process order event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private String headerString(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
