package com.bhook.financial.messaging;

import com.bhook.common.events.OrderCreatedEvent;
import com.bhook.common.events.OrderStatusChangedEvent;
import com.bhook.common.events.PaymentSucceededEvent;
import com.bhook.common.events.RefundProcessedEvent;
import com.bhook.common.events.Topics;
import com.bhook.financial.service.LedgerService;
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
public class FinancialEventsListener {

    private final ObjectMapper objectMapper;
    private final LedgerService ledgerService;

    @KafkaListener(topics = {Topics.ORDER_EVENTS, Topics.PAYMENT_EVENTS}, groupId = "bhook-financial")
    @Transactional
    public void onEvent(ConsumerRecord<String, String> record) {
        String type = header(record, "event-type");
        try {
            switch (type) {
                case OrderCreatedEvent.EVENT_TYPE -> {
                    OrderCreatedEvent evt = objectMapper.readValue(record.value(), OrderCreatedEvent.class);
                        ledgerService.recordOrderTotals(evt.orderId(), evt.vendorId(), evt.campusId(),
                            evt.userId(), evt.currency(), evt.totalMinor(), evt.commissionBps());
                }
                case PaymentSucceededEvent.EVENT_TYPE -> {
                    PaymentSucceededEvent evt = objectMapper.readValue(record.value(), PaymentSucceededEvent.class);
                    ledgerService.recordPayment(evt.orderId(), evt.amountMinor(), evt.currency());
                }
                case RefundProcessedEvent.EVENT_TYPE -> {
                    RefundProcessedEvent evt = objectMapper.readValue(record.value(), RefundProcessedEvent.class);
                    ledgerService.recordRefund(evt.orderId(), evt.amountMinor(), evt.currency(), evt.reason());
                }
                case OrderStatusChangedEvent.EVENT_TYPE -> {
                    OrderStatusChangedEvent evt = objectMapper.readValue(record.value(), OrderStatusChangedEvent.class);
                    if ("COMPLETED".equals(evt.toStatus())) {
                        ledgerService.closeOrderFinancials(evt.orderId());
                    }
                }
                default -> log.debug("Ignoring event type: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to process financial event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private String header(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
