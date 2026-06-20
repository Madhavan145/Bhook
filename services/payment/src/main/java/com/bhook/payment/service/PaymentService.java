package com.bhook.payment.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.events.PaymentSucceededEvent;
import com.bhook.common.events.Topics;
import com.bhook.payment.domain.PaymentAttempt;
import com.bhook.payment.domain.PaymentAttemptStatus;
import com.bhook.payment.outbox.OutboxWriter;
import com.bhook.payment.provider.PaymentProvider;
import com.bhook.payment.repository.PaymentAttemptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentAttemptRepository attemptRepository;
    private final PaymentProvider provider;
    private final OutboxWriter outbox;

    @Value("${bhook.payment.auto-succeed-stub-payments:false}")
    private boolean autoSucceedStubPayments;

    @Transactional
    public PaymentAttempt createAttempt(UUID orderId, long amountMinor, String currency) {
        PaymentAttempt attempt = attemptRepository.save(PaymentAttempt.builder()
                .orderId(orderId)
                .provider(provider.name())
                .amountMinor(amountMinor)
                .currency(currency)
                .status(PaymentAttemptStatus.PENDING)
                .expiresAt(Instant.now().plus(15, ChronoUnit.MINUTES))
                .build());
        PaymentProvider.CheckoutHandoff handoff = provider.createCheckout(attempt.getId(), orderId, amountMinor, currency);
        attempt.setProviderReference(handoff.providerReference());
        attempt = attemptRepository.save(attempt);
        if (autoSucceedStubPayments) {
            attempt = simulateSuccess(attempt.getId());
        }
        return attempt;
    }

    @Transactional
    public PaymentAttempt handleCallback(String rawBody, String signature) {
        if (!provider.verifyWebhookSignature(rawBody, signature)) {
            throw BhookException.unauthorized("Invalid webhook signature");
        }
        PaymentProvider.CallbackResult result = provider.parseCallback(rawBody);
        if (result.callbackEventId() == null) throw BhookException.validation("Missing callback event id");

        return attemptRepository.findByCallbackEventId(result.callbackEventId()).orElseGet(() -> {
            if (result.providerReference() == null) {
                throw BhookException.notFound("Payment attempt not found");
            }
            PaymentAttempt attempt = attemptRepository
                    .findByProviderAndProviderReference(provider.name(), result.providerReference())
                    .orElseThrow(() -> BhookException.notFound("Payment attempt not found"));
            attempt.setCallbackEventId(result.callbackEventId());
            if (result.success()) {
                if (attempt.getStatus() != PaymentAttemptStatus.SUCCESS) {
                    attempt.setStatus(PaymentAttemptStatus.SUCCESS);
                    outbox.write(Topics.PAYMENT_EVENTS, "PaymentAttempt", attempt.getId().toString(),
                            PaymentSucceededEvent.EVENT_TYPE,
                            new PaymentSucceededEvent(attempt.getId(), attempt.getOrderId(),
                                    attempt.getProvider(), attempt.getProviderReference(),
                                    attempt.getAmountMinor(), attempt.getCurrency(), Instant.now()));
                }
            } else {
                attempt.setStatus(PaymentAttemptStatus.FAILED);
            }
            return attemptRepository.save(attempt);
        });
    }

    @Transactional
    public PaymentAttempt simulateSuccess(UUID attemptId) {
        PaymentAttempt attempt = attemptRepository.findById(attemptId)
                .orElseThrow(() -> BhookException.notFound("Payment attempt not found"));
        if (attempt.getStatus() == PaymentAttemptStatus.SUCCESS) return attempt;
        attempt.setStatus(PaymentAttemptStatus.SUCCESS);
        attempt.setCallbackEventId("dev-simulate-" + UUID.randomUUID());
        attempt = attemptRepository.save(attempt);
        outbox.write(Topics.PAYMENT_EVENTS, "PaymentAttempt", attempt.getId().toString(),
                PaymentSucceededEvent.EVENT_TYPE,
                new PaymentSucceededEvent(attempt.getId(), attempt.getOrderId(),
                        attempt.getProvider(), attempt.getProviderReference(),
                        attempt.getAmountMinor(), attempt.getCurrency(), Instant.now()));
        log.info("Simulated payment success for attempt {}", attempt.getId());
        return attempt;
    }
}
