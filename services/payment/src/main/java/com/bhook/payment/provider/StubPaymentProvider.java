package com.bhook.payment.provider;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class StubPaymentProvider implements PaymentProvider {

    private final ObjectMapper objectMapper;

    @Value("${bhook.payment.webhook-secret}")
    private String webhookSecret;

    @Override
    public String name() { return "STUB"; }

    @Override
    public CheckoutHandoff createCheckout(UUID attemptId, UUID orderId, long amountMinor, String currency) {
        String providerRef = "stub_" + attemptId.toString().substring(0, 8);
        String token = "stub_token_" + attemptId;
        String url = "http://localhost:8086/dev/checkout?attemptId=" + attemptId;
        return new CheckoutHandoff(providerRef, url, token, 900L);
    }

    @Override
    public boolean verifyWebhookSignature(String rawBody, String signatureHeader) {
        if (signatureHeader == null) return false;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8));
            String expected = HexFormat.of().formatHex(hash);
            return constantTimeEquals(expected, signatureHeader);
        } catch (Exception e) {
            log.warn("Webhook signature verify failed: {}", e.toString());
            return false;
        }
    }

    @Override
    public CallbackResult parseCallback(String rawBody) {
        try {
            JsonNode json = objectMapper.readTree(rawBody);
            return new CallbackResult(
                    text(json, "providerReference"),
                    text(json, "eventId"),
                    "SUCCESS".equalsIgnoreCase(text(json, "status")),
                    text(json, "reason")
            );
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid webhook payload", e);
        }
    }

    private String text(JsonNode n, String field) {
        JsonNode v = n.get(field);
        return v == null || v.isNull() ? null : v.asText();
    }

    private boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) return false;
        int r = 0;
        for (int i = 0; i < a.length(); i++) r |= a.charAt(i) ^ b.charAt(i);
        return r == 0;
    }
}
