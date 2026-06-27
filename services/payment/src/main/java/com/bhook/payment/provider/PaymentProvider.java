package com.bhook.payment.provider;

import java.util.UUID;

public interface PaymentProvider {
    String name();
    CheckoutHandoff createCheckout(UUID attemptId, UUID orderId, long amountMinor, String currency);
    boolean verifyWebhookSignature(String rawBody, String signatureHeader);
    CallbackResult parseCallback(String rawBody);

    record CheckoutHandoff(String providerReference, String checkoutUrl, String providerToken, long expiresInSeconds) {}
    record CallbackResult(String providerReference, String callbackEventId, boolean success, String reason) {}
}
