package com.bhook.order.messaging;

import com.bhook.common.events.DeliveryAssignedEvent;
import com.bhook.common.events.DeliveryStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.bhook.order.domain.OrderEntity;
import com.bhook.order.domain.OrderStatus;
import com.bhook.order.repository.OrderRepository;
import com.bhook.order.service.OrderService;
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
public class DeliveryEventsListener {

    private final ObjectMapper objectMapper;
    private final OrderRepository orderRepository;
    private final OrderService orderService;

    @KafkaListener(topics = Topics.DELIVERY_EVENTS, groupId = "bhook-order")
    @Transactional
    public void onDeliveryEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            if (DeliveryAssignedEvent.EVENT_TYPE.equals(type)) {
                DeliveryAssignedEvent evt = objectMapper.readValue(record.value(), DeliveryAssignedEvent.class);
                transition(evt.orderId(), OrderStatus.READY_FOR_PICKUP, OrderStatus.DELIVERY_ASSIGNED, "DELIVERY_ASSIGNED");
            } else if (DeliveryStatusChangedEvent.EVENT_TYPE.equals(type)) {
                DeliveryStatusChangedEvent evt = objectMapper.readValue(record.value(), DeliveryStatusChangedEvent.class);
                switch (evt.toStatus()) {
                    case "PICKED_UP"  -> transition(evt.orderId(), null, OrderStatus.PICKED_UP, "PARTNER_PICKED_UP");
                    case "COMPLETED"  -> transition(evt.orderId(), null, OrderStatus.COMPLETED, "DELIVERY_COMPLETED");
                    default -> log.debug("Ignoring delivery status transition {}", evt.toStatus());
                }
            } else {
                log.debug("Ignoring delivery event: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to process delivery event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private void transition(java.util.UUID orderId, OrderStatus expected, OrderStatus target, String reason) {
        OrderEntity order = orderRepository.findById(orderId).orElse(null);
        if (order == null) {
            log.warn("Order {} not found for delivery event", orderId);
            return;
        }
        if (expected != null && order.getStatus() != expected) {
            log.info("Ignoring delivery event for order {} in status {} (expected {})", orderId, order.getStatus(), expected);
            return;
        }
        orderService.transition(order, target, "DELIVERY_SERVICE", null, reason);
    }

    private String headerString(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
