package com.bhook.payment.messaging;

import com.bhook.common.events.OrderCreatedEvent;
import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.Topics;
import com.bhook.payment.service.PaymentService;
import com.bhook.payment.service.RefundService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Header;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.Set;

@Slf4j
@Component
@RequiredArgsConstructor
public class OrderEventsListener {

    private static final Set<String> REFUND_TRIGGERS = Set.of("VENDOR_REJECTED", "CANCELLED");

    private final ObjectMapper objectMapper;
    private final PaymentService paymentService;
    private final RefundService refundService;

    @KafkaListener(topics = Topics.ORDER_EVENTS, groupId = "bhook-payment")
    @Transactional
    public void onOrderEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            if (OrderCreatedEvent.EVENT_TYPE.equals(type)) {
                OrderCreatedEvent evt = objectMapper.readValue(record.value(), OrderCreatedEvent.class);
                paymentService.createAttempt(evt.orderId(), evt.totalMinor(), evt.currency());
                log.info("Payment attempt created for order {}", evt.orderId());
            } else if (OrderStatusChangedEvent.EVENT_TYPE.equals(type)) {
                OrderStatusChangedEvent evt = objectMapper.readValue(record.value(), OrderStatusChangedEvent.class);
                if (REFUND_TRIGGERS.contains(evt.toStatus()) && "PAID".equals(evt.fromStatus())) {
                    refundService.refundOrder(evt.orderId(), "AUTO_REFUND_" + evt.toStatus());
                }
            } else {
                log.debug("Ignoring order event type: {}", type);
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
