package com.bhook.order.messaging;

import com.bhook.common.events.PaymentSucceededEvent;
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
public class PaymentEventsListener {

    private final ObjectMapper objectMapper;
    private final OrderRepository orderRepository;
    private final OrderService orderService;

    @KafkaListener(topics = Topics.PAYMENT_EVENTS, groupId = "bhook-order")
    @Transactional
    public void onPaymentEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            if (PaymentSucceededEvent.EVENT_TYPE.equals(type)) {
                PaymentSucceededEvent evt = objectMapper.readValue(record.value(), PaymentSucceededEvent.class);
                OrderEntity order = orderRepository.findById(evt.orderId()).orElse(null);
                if (order == null) {
                    log.warn("Received PaymentSucceeded for unknown order {}", evt.orderId());
                    return;
                }
                if (order.getStatus() != OrderStatus.PAYMENT_PENDING) {
                    log.info("Ignoring PaymentSucceeded for order {} in status {}", order.getId(), order.getStatus());
                    return;
                }
                orderService.transition(order, OrderStatus.PAID, "PAYMENT_SERVICE", null,
                        "PROVIDER_REF=" + evt.providerReference());
                log.info("Order {} moved to PAID via payment {}", order.getId(), evt.paymentAttemptId());
                if (order.isAutoAccept()) {
                    orderService.transition(order, OrderStatus.VENDOR_ACCEPTED, "SYSTEM", null, "AUTO_ACCEPTED");
                    log.info("Order {} auto-accepted for vendor {}", order.getId(), order.getVendorId());
                }
            } else {
                log.debug("Ignoring payment event type: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to process payment event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private String headerString(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
