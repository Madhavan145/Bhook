package com.bhook.tracking.messaging;

import com.bhook.common.events.DeliveryAssignedEvent;
import com.bhook.common.events.DeliveryStatusChangedEvent;
import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.bhook.tracking.model.OrderTrackingState;
import com.bhook.tracking.service.TrackingBroadcaster;
import com.bhook.tracking.service.TrackingStore;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Header;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
public class TrackingEventsListener {

    private final ObjectMapper objectMapper;
    private final TrackingStore store;
    private final TrackingBroadcaster broadcaster;

    @KafkaListener(topics = {Topics.ORDER_EVENTS, Topics.DELIVERY_EVENTS}, groupId = "bhook-tracking")
    public void onEvent(ConsumerRecord<String, String> record) {
        String type = header(record, "event-type");
        try {
            OrderTrackingState updated = null;
            switch (type) {
                case DeliveryAssignedEvent.EVENT_TYPE -> {
                    DeliveryAssignedEvent evt = objectMapper.readValue(record.value(), DeliveryAssignedEvent.class);
                    store.indexOrderPartner(evt.orderId(), evt.partnerId());
                    updated = store.mergeStatus(evt.orderId(), evt.partnerId(), "DELIVERY_ASSIGNED");
                    broadcaster.broadcast(evt.orderId(), updated);
                }
                case DeliveryStatusChangedEvent.EVENT_TYPE -> {
                    DeliveryStatusChangedEvent evt = objectMapper.readValue(record.value(), DeliveryStatusChangedEvent.class);
                    updated = store.mergeStatus(evt.orderId(), evt.partnerId(), evt.toStatus());
                    broadcaster.broadcast(evt.orderId(), updated);
                }
                case OrderStatusChangedEvent.EVENT_TYPE -> {
                    OrderStatusChangedEvent evt = objectMapper.readValue(record.value(), OrderStatusChangedEvent.class);
                    updated = store.mergeStatus(evt.orderId(), null, evt.toStatus());
                    broadcaster.broadcast(evt.orderId(), updated);
                }
                default -> log.debug("Ignoring tracking event: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to update tracking for type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private String header(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
