package com.bhook.identity.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.events.Topics;
import com.bhook.common.events.UserRegisteredEvent;
import com.bhook.common.security.JwtProperties;
import com.bhook.common.security.JwtService;
import com.bhook.identity.api.dto.*;
import com.bhook.identity.domain.RoleName;
import com.bhook.identity.domain.User;
import com.bhook.identity.domain.UserRole;
import com.bhook.identity.domain.UserSession;
import com.bhook.identity.domain.UserStatus;
import com.bhook.identity.outbox.OutboxWriter;
import com.bhook.identity.repository.UserRepository;
import com.bhook.identity.repository.UserRoleRepository;
import com.bhook.identity.repository.UserSessionRepository;
import com.bhook.identity.support.HashUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final UserSessionRepository userSessionRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;
    private final OutboxWriter outboxWriter;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public TokenResponse register(RegisterRequest req) {
        if (req.accountType() != null && "CUSTOMER".equalsIgnoreCase(req.accountType())) {
            throw BhookException.validation("Customer accounts must be created via /auth/signup/email-challenge then /auth/signup/complete");
        }
        if (userRepository.existsByEmailIgnoreCase(req.email())) {
            throw BhookException.conflict("Email already registered");
        }
        if (req.phoneE164() != null && userRepository.existsByPhoneE164(req.phoneE164())) {
            throw BhookException.conflict("Phone already registered");
        }

        User user = User.builder()
                .email(req.email().toLowerCase())
                .phoneE164(req.phoneE164())
                .passwordHash(passwordEncoder.encode(req.password()))
                .displayName(req.displayName())
                .status(UserStatus.REGISTERED)
                .build();
        user = userRepository.save(user);

        RoleName defaultRole = resolveDefaultRole(req.accountType());
        userRoleRepository.save(UserRole.builder()
                .userId(user.getId())
                .roleName(defaultRole)
                .build());

        outboxWriter.write(
                Topics.IDENTITY_USER_EVENTS,
                "User",
                user.getId().toString(),
                UserRegisteredEvent.EVENT_TYPE,
                new UserRegisteredEvent(
                        user.getId(),
                        user.getEmail(),
                        user.getPhoneE164(),
                        user.getDisplayName(),
                        List.of(defaultRole.name()),
                        user.getStatus().name(),
                        Instant.now()
                )
        );

        return issueTokens(user, null);
    }

    @Transactional
    public ProvisionUserResponse provisionUser(ProvisionUserRequest req) {
        if (userRepository.existsByEmailIgnoreCase(req.email())) {
            throw BhookException.conflict("Email already registered");
        }
        if (req.phoneE164() != null && !req.phoneE164().isBlank()
                && userRepository.existsByPhoneE164(req.phoneE164())) {
            throw BhookException.conflict("Phone already registered");
        }

        boolean generated = req.password() == null || req.password().isBlank();
        String rawPassword = generated ? generateTemporaryPassword() : req.password();

        User user = User.builder()
                .email(req.email().toLowerCase())
                .phoneE164(req.phoneE164() == null || req.phoneE164().isBlank() ? null : req.phoneE164())
                .passwordHash(passwordEncoder.encode(rawPassword))
                .displayName(req.displayName())
                .status(UserStatus.ACTIVE)
                .build();
        user = userRepository.save(user);

        List<RoleName> roles = req.roles().stream().distinct().toList();
        for (RoleName role : roles) {
            userRoleRepository.save(UserRole.builder().userId(user.getId()).roleName(role).build());
        }

        outboxWriter.write(
                Topics.IDENTITY_USER_EVENTS,
                "User",
                user.getId().toString(),
                UserRegisteredEvent.EVENT_TYPE,
                new UserRegisteredEvent(
                        user.getId(), user.getEmail(), user.getPhoneE164(), user.getDisplayName(),
                        roles.stream().map(Enum::name).toList(), user.getStatus().name(), Instant.now())
        );

        return new ProvisionUserResponse(
                user.getId(), user.getEmail(), user.getDisplayName(),
                roles.stream().map(Enum::name).toList(),
                generated ? rawPassword : null
        );
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        User user = userRepository.findByEmailIgnoreCase(req.email())
                .orElseThrow(() -> BhookException.unauthorized("Invalid credentials"));
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw BhookException.unauthorized("Invalid credentials");
        }
        if (user.getStatus() == UserStatus.BLOCKED || user.getStatus() == UserStatus.DEACTIVATED) {
            throw BhookException.forbidden("Account is not active");
        }
        return issueTokens(user, req.deviceId());
    }

    @Transactional
    public TokenResponse refresh(RefreshRequest req) {
        String hash = HashUtils.sha256(req.refreshToken());
        UserSession session = userSessionRepository.findByRefreshTokenHash(hash)
                .orElseThrow(() -> BhookException.unauthorized("Invalid refresh token"));
        if (session.getRevokedAt() != null || session.getExpiresAt().isBefore(Instant.now())) {
            throw BhookException.unauthorized("Refresh token expired or revoked");
        }
        User user = userRepository.findById(session.getUserId())
                .orElseThrow(() -> BhookException.unauthorized("User not found"));

        session.setRevokedAt(Instant.now());
        userSessionRepository.save(session);
        return issueTokens(user, session.getDeviceId());
    }

    @Transactional
    public void logout(UUID sessionId) {
        userSessionRepository.findById(sessionId).ifPresent(s -> {
            if (s.getRevokedAt() == null) {
                s.setRevokedAt(Instant.now());
                userSessionRepository.save(s);
            }
        });
    }

    @Transactional
    public UserSummary me(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BhookException.unauthorized("User not found"));
        List<String> roles = userRoleRepository.findByUserId(user.getId()).stream()
                .map(r -> r.getRoleName().name()).distinct().toList();
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getStatus().name(), roles);
    }

    private TokenResponse issueTokens(User user, String deviceId) {
        List<UserRole> roles = userRoleRepository.findByUserId(user.getId());
        List<String> roleNames = roles.stream().map(r -> r.getRoleName().name()).distinct().toList();
        List<String> permissions = List.of();

        String refreshToken = generateRefreshToken();
        UserSession session = UserSession.builder()
                .userId(user.getId())
                .refreshTokenHash(HashUtils.sha256(refreshToken))
                .deviceId(deviceId)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(jwtProperties.refreshTokenTtlSeconds()))
                .build();
        session = userSessionRepository.save(session);

        String accessToken = jwtService.issueAccessToken(user.getId(), session.getId().toString(), roleNames, permissions);

        return new TokenResponse(
                accessToken,
                refreshToken,
                jwtProperties.accessTokenTtlSeconds(),
                new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getStatus().name(), roleNames)
        );
    }

    private RoleName resolveDefaultRole(String accountType) {
        if (accountType == null) return RoleName.CUSTOMER;
        return switch (accountType.toUpperCase()) {
            case "VENDOR" -> RoleName.VENDOR_OWNER;
            case "DELIVERY" -> RoleName.DELIVERY_PARTNER;
            case "PLATFORM" -> RoleName.PLATFORM_SUPPORT;
            default -> RoleName.CUSTOMER;
        };
    }

    private String generateRefreshToken() {
        byte[] bytes = new byte[48];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String generateTemporaryPassword() {
        // Ambiguity-free alphabet plus mandatory symbol/digit for policy-friendly temp creds.
        String alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) {
            sb.append(alphabet.charAt(random.nextInt(alphabet.length())));
        }
        sb.append('#').append(random.nextInt(10));
        return sb.toString();
    }
}
