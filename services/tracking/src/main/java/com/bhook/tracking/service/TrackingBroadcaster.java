package com.bhook.tracking.service;

import com.bhook.tracking.model.OrderTrackingState;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class TrackingBroadcaster {

    private final SimpMessagingTemplate messagingTemplate;

    public void broadcast(UUID orderId, OrderTrackingState state) {
        if (state == null) return;
        try {
            messagingTemplate.convertAndSend("/topic/orders/" + orderId, state);
        } catch (Exception e) {
            log.warn("STOMP broadcast failed for order {}: {}", orderId, e.toString());
        }
    }
}
