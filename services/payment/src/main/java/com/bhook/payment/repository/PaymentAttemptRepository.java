package com.bhook.payment.repository;

import com.bhook.payment.domain.PaymentAttempt;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PaymentAttemptRepository extends JpaRepository<PaymentAttempt, UUID> {
    List<PaymentAttempt> findByOrderIdOrderByCreatedAtDesc(UUID orderId);
    Optional<PaymentAttempt> findByCallbackEventId(String callbackEventId);
    Optional<PaymentAttempt> findByProviderAndProviderReference(String provider, String providerReference);
}
