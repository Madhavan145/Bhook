package com.bhook.payment.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.events.RefundProcessedEvent;
import com.bhook.common.events.Topics;
import com.bhook.payment.domain.PaymentAttempt;
import com.bhook.payment.domain.PaymentAttemptStatus;
import com.bhook.payment.domain.Refund;
import com.bhook.payment.outbox.OutboxWriter;
import com.bhook.payment.repository.PaymentAttemptRepository;
import com.bhook.payment.repository.RefundRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefundService {

    private final PaymentAttemptRepository attemptRepository;
    private final RefundRepository refundRepository;
    private final OutboxWriter outbox;

    @Transactional
    public Refund refundOrder(UUID orderId, String reason) {
        Refund existing = refundRepository.findByOrderIdAndStatus(orderId, "SUCCESS").orElse(null);
        if (existing != null) return existing;

        List<PaymentAttempt> attempts = attemptRepository.findByOrderIdOrderByCreatedAtDesc(orderId);
        PaymentAttempt success = attempts.stream()
                .filter(a -> a.getStatus() == PaymentAttemptStatus.SUCCESS)
                .findFirst()
                .orElseThrow(() -> BhookException.notFound("No successful payment to refund"));

        Refund refund;
        try {
            refund = refundRepository.save(Refund.builder()
                    .orderId(orderId)
                    .paymentAttemptId(success.getId())
                    .amountMinor(success.getAmountMinor())
                    .reason(reason)
                    .status("SUCCESS")
                    .providerReference("refund_" + UUID.randomUUID().toString().substring(0, 8))
                    .build());
        } catch (DataIntegrityViolationException dup) {
            log.info("Refund already recorded for order {} (raced with concurrent request)", orderId);
            return refundRepository.findByOrderIdAndStatus(orderId, "SUCCESS")
                    .orElseThrow(() -> dup);
        }

        outbox.write(Topics.PAYMENT_EVENTS, "Refund", refund.getId().toString(),
                RefundProcessedEvent.EVENT_TYPE,
                new RefundProcessedEvent(refund.getId(), success.getId(), orderId,
                        success.getProvider(), refund.getAmountMinor(), success.getCurrency(),
                        reason, Instant.now()));
        log.info("Refund {} recorded for order {}", refund.getId(), orderId);
        return refund;
    }
}
