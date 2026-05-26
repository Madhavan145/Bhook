package com.bhook.customer.messaging;

import com.bhook.common.events.CustomerSignupCompletedEvent;
import com.bhook.common.events.Topics;
import com.bhook.common.events.UserRegisteredEvent;
import com.bhook.customer.service.CustomerProfileService;
import com.bhook.customer.service.VerificationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.header.Header;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
public class IdentityEventsListener {

    private final ObjectMapper objectMapper;
    private final CustomerProfileService profileService;
    private final VerificationService verificationService;

    @KafkaListener(topics = Topics.IDENTITY_USER_EVENTS, groupId = "bhook-customer")
    public void onIdentityEvent(ConsumerRecord<String, String> record) {
        String type = headerString(record, "event-type");
        try {
            switch (type) {
                case UserRegisteredEvent.EVENT_TYPE -> handleUserRegistered(record.value());
                case CustomerSignupCompletedEvent.EVENT_TYPE -> handleSignupCompleted(record.value());
                default -> log.debug("Ignoring identity event type: {}", type);
            }
        } catch (Exception e) {
            log.error("Failed to process identity event type={} payload={}", type, record.value(), e);
            throw new RuntimeException(e);
        }
    }

    private void handleUserRegistered(String payload) throws Exception {
        UserRegisteredEvent event = objectMapper.readValue(payload, UserRegisteredEvent.class);
        if (event.roles() != null && event.roles().contains("CUSTOMER")) {
            profileService.ensureProfile(event.userId(), event.displayName(), event.email(), event.phoneE164());
            log.info("Customer profile bootstrapped user_id={}", event.userId());
        }
    }

    private void handleSignupCompleted(String payload) throws Exception {
        CustomerSignupCompletedEvent event = objectMapper.readValue(payload, CustomerSignupCompletedEvent.class);
        verificationService.bootstrapFromSignup(
                event.userId(), event.email(), event.phoneE164(), event.displayName(),
                event.campusId(), event.membershipType(), event.autoVerify(), event.verifiedDomain()
        );
        log.info("Customer signup bootstrapped user_id={} campus_id={} auto_verify={}",
                event.userId(), event.campusId(), event.autoVerify());
    }

    private String headerString(ConsumerRecord<?, ?> record, String key) {
        Header h = record.headers().lastHeader(key);
        return h == null ? "" : new String(h.value(), StandardCharsets.UTF_8);
    }
}
