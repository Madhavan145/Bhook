package com.bhook.order.messaging;

import com.bhook.common.events.RefundProcessedEvent;
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
public class RefundEventsListener {

    private final ObjectMapper objectMapper;
    private final OrderRepository orderRepository;
    private final OrderService orderService;

    @KafkaListener(topics = Topics.PAYMENT_EVENTS, groupId = "bhook-order-refund")
    @Transactional
    public void onEvent(ConsumerRecord<String, String> record) {
        String type = header(record, "event-type");
        try {
            if (RefundProcessedEvent.EVENT_TYPE.equals(type)) {
                RefundProcessedEvent evt = objectMapper.readValue(record.value(), RefundProcessedEvent.class);
                OrderEntity order = orderRepository.findById(evt.orderId()).orElse(null);
                if (order == null) {
                    log.warn("Refund event for unknown order {}", evt.orderId());
                    return;
                }
                if (order.getStatus() == OrderStatus.REFUNDED) return;
                orderService.transition(order, OrderStatus.REFUNDED, "PAYMENT_SERVICE", null,
                        "REFUND_ID=" + evt.refundId());
            }
        } catch (Exception e) {
            log.error("Failed to process refund event payload={}", record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private String header(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
