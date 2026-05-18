package com.bhook.identity.service;

import com.bhook.common.error.BhookException;
import com.bhook.identity.domain.OtpChallenge;
import com.bhook.identity.domain.OtpChannel;
import com.bhook.identity.domain.OtpPurpose;
import com.bhook.identity.repository.OtpChallengeRepository;
import com.bhook.identity.support.HashUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class OtpService {

    private static final int OTP_TTL_SECONDS = 300;
    private static final int OTP_LENGTH = 6;
    private final OtpChallengeRepository repository;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public UUID issue(OtpChannel channel, OtpPurpose purpose, String destination) {
        return issueWithMetadata(channel, purpose, destination, null);
    }

    @Transactional
    public UUID issueWithMetadata(OtpChannel channel, OtpPurpose purpose, String destination, String metadataJson) {
        String code = generateNumericCode();
        OtpChallenge challenge = OtpChallenge.builder()
                .channel(channel)
                .purpose(purpose)
                .destination(destination.toLowerCase())
                .codeHash(HashUtils.sha256(code))
                .maxAttempts(5)
                .expiresAt(Instant.now().plus(OTP_TTL_SECONDS, ChronoUnit.SECONDS))
                .metadata(metadataJson)
                .build();
        challenge = repository.save(challenge);
        log.info("OTP issued challenge_id={} channel={} purpose={} destination_masked={}",
                challenge.getId(), channel, purpose, maskDestination(destination));
        if (log.isDebugEnabled()) {
            log.debug("[DEV-ONLY] OTP code for challenge {} = {}", challenge.getId(), code);
        }
        return challenge.getId();
    }

    @Transactional
    public OtpChallenge verify(UUID challengeId, String code) {
        OtpChallenge challenge = repository.findById(challengeId)
                .orElseThrow(() -> BhookException.unauthorized("Invalid OTP challenge"));
        if (challenge.getConsumedAt() != null) {
            throw BhookException.unauthorized("OTP already used");
        }
        if (challenge.getExpiresAt().isBefore(Instant.now())) {
            throw BhookException.unauthorized("OTP expired");
        }
        if (challenge.getAttempts() >= challenge.getMaxAttempts()) {
            throw BhookException.unauthorized("OTP attempt limit exceeded");
        }
        challenge.setAttempts(challenge.getAttempts() + 1);
        if (!HashUtils.sha256(code).equals(challenge.getCodeHash())) {
            repository.save(challenge);
            throw BhookException.unauthorized("Invalid OTP");
        }
        challenge.setConsumedAt(Instant.now());
        return repository.save(challenge);
    }

    private String generateNumericCode() {
        StringBuilder sb = new StringBuilder(OTP_LENGTH);
        for (int i = 0; i < OTP_LENGTH; i++) {
            sb.append(random.nextInt(10));
        }
        return sb.toString();
    }

    private String maskDestination(String destination) {
        if (destination == null || destination.length() < 4) return "***";
        int keep = Math.min(3, destination.length() - 2);
        return destination.substring(0, keep) + "***" + destination.substring(destination.length() - 2);
    }
}
