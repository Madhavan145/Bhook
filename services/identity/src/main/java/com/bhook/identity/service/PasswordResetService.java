package com.bhook.identity.service;

import com.bhook.common.error.BhookException;
import com.bhook.identity.domain.OtpChallenge;
import com.bhook.identity.domain.OtpChannel;
import com.bhook.identity.domain.OtpPurpose;
import com.bhook.identity.domain.PasswordResetToken;
import com.bhook.identity.domain.User;
import com.bhook.identity.repository.PasswordResetTokenRepository;
import com.bhook.identity.repository.UserRepository;
import com.bhook.identity.support.HashUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PasswordResetService {

    private static final int TOKEN_TTL_MINUTES = 30;
    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpService otpService;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public UUID requestOtpReset(String email) {
        return userRepository.findByEmailIgnoreCase(email)
                .map(user -> otpService.issue(OtpChannel.EMAIL, OtpPurpose.PASSWORD_RESET,
                        user.getEmail()))
                .orElseGet(() -> otpService.issue(OtpChannel.EMAIL, OtpPurpose.PASSWORD_RESET,
                        email));
    }

    @Transactional
    public void confirmOtpReset(UUID challengeId, String code, String newPassword) {
        OtpChallenge challenge = otpService.verify(challengeId, code);
        if (challenge.getPurpose() != OtpPurpose.PASSWORD_RESET) {
            throw BhookException.unauthorized("Invalid password reset challenge");
        }
        User user = userRepository.findByEmailIgnoreCase(challenge.getDestination())
                .orElseThrow(() -> BhookException.unauthorized("Invalid password reset challenge"));
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    @Transactional
    public void requestReset(String email) {
        userRepository.findByEmailIgnoreCase(email).ifPresent(user -> {
            String rawToken = generateToken();
            PasswordResetToken record = PasswordResetToken.builder()
                    .userId(user.getId())
                    .tokenHash(HashUtils.sha256(rawToken))
                    .expiresAt(Instant.now().plus(TOKEN_TTL_MINUTES, ChronoUnit.MINUTES))
                    .build();
            tokenRepository.save(record);
            log.info("Password reset requested user_id={} record_id={}", user.getId(), record.getId());
            if (log.isDebugEnabled()) {
                log.debug("[DEV-ONLY] Password reset token = {}", rawToken);
            }
        });
    }

    @Transactional
    public void confirm(String rawToken, String newPassword) {
        PasswordResetToken record = tokenRepository.findByTokenHash(HashUtils.sha256(rawToken))
                .orElseThrow(() -> BhookException.unauthorized("Invalid reset token"));
        if (record.getConsumedAt() != null) {
            throw BhookException.unauthorized("Reset token already used");
        }
        if (record.getExpiresAt().isBefore(Instant.now())) {
            throw BhookException.unauthorized("Reset token expired");
        }
        User user = userRepository.findById(record.getUserId())
                .orElseThrow(() -> BhookException.unauthorized("User not found"));
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        record.setConsumedAt(Instant.now());
        tokenRepository.save(record);
    }

    private String generateToken() {
        byte[] bytes = new byte[48];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
