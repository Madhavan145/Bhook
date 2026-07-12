package com.bhook.tracking.service;

import com.bhook.tracking.model.OrderTrackingState;
import com.bhook.tracking.model.PartnerLocation;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TrackingStore {

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    @Value("${bhook.tracking.location-ttl-seconds:300}") private long locationTtlSeconds;
    @Value("${bhook.tracking.order-ttl-seconds:3600}") private long orderTtlSeconds;

    public void writePartnerLocation(PartnerLocation loc) {
        redis.opsForValue().set(partnerKey(loc.partnerId()), toJson(loc), Duration.ofSeconds(locationTtlSeconds));
    }

    public Optional<PartnerLocation> readPartnerLocation(UUID partnerId) {
        String raw = redis.opsForValue().get(partnerKey(partnerId));
        return raw == null ? Optional.empty() : Optional.of(fromJson(raw, PartnerLocation.class));
    }

    public void updateOrderState(OrderTrackingState state) {
        redis.opsForValue().set(orderKey(state.orderId()), toJson(state), Duration.ofSeconds(orderTtlSeconds));
    }

    public Optional<OrderTrackingState> readOrderState(UUID orderId) {
        String raw = redis.opsForValue().get(orderKey(orderId));
        return raw == null ? Optional.empty() : Optional.of(fromJson(raw, OrderTrackingState.class));
    }

    public OrderTrackingState mergeStatus(UUID orderId, UUID partnerId, String status) {
        OrderTrackingState current = readOrderState(orderId).orElse(null);
        PartnerLocation loc = partnerId != null ? readPartnerLocation(partnerId).orElse(null) : null;
        UUID resolvedPartner = partnerId != null ? partnerId : (current == null ? null : current.partnerId());
        OrderTrackingState updated = new OrderTrackingState(orderId, resolvedPartner, status, loc, Instant.now());
        updateOrderState(updated);
        return updated;
    }

    public OrderTrackingState mergeLocation(UUID partnerId, PartnerLocation location) {
        writePartnerLocation(location);
        String pattern = "tracking:order:*:partner:" + partnerId;
        java.util.Set<String> keys = redis.keys(pattern);
        OrderTrackingState result = null;
        if (keys != null) {
            for (String k : keys) {
                String orderKeyStr = k.replace(":partner:" + partnerId, "").replace("tracking:order:", "");
                UUID orderId = UUID.fromString(orderKeyStr);
                OrderTrackingState current = readOrderState(orderId).orElse(null);
                if (current != null) {
                    result = new OrderTrackingState(orderId, partnerId, current.status(), location, Instant.now());
                    updateOrderState(result);
                }
            }
        }
        return result;
    }

    public void indexOrderPartner(UUID orderId, UUID partnerId) {
        redis.opsForValue().set(orderPartnerIndex(orderId, partnerId), "1", Duration.ofSeconds(orderTtlSeconds));
    }

    private String partnerKey(UUID partnerId) { return "tracking:partner:" + partnerId; }
    private String orderKey(UUID orderId) { return "tracking:order:" + orderId; }
    private String orderPartnerIndex(UUID orderId, UUID partnerId) {
        return "tracking:order:" + orderId + ":partner:" + Objects.requireNonNull(partnerId);
    }

    private String toJson(Object o) {
        try { return objectMapper.writeValueAsString(o); }
        catch (JsonProcessingException e) { throw new IllegalStateException(e); }
    }

    private <T> T fromJson(String s, Class<T> t) {
        try { return objectMapper.readValue(s, t); }
        catch (Exception e) { throw new IllegalStateException(e); }
    }
}
