package com.bhook.identity.service;

import com.bhook.common.error.BhookException;
import com.bhook.common.error.ErrorCode;
import com.bhook.common.events.CustomerSignupCompletedEvent;
import com.bhook.common.events.Topics;
import com.bhook.common.security.JwtProperties;
import com.bhook.common.security.JwtService;
import com.bhook.identity.api.dto.CompleteSignupRequest;
import com.bhook.identity.api.dto.EmailChallengeRequest;
import com.bhook.identity.api.dto.EmailChallengeResponse;
import com.bhook.identity.api.dto.TokenResponse;
import com.bhook.identity.api.dto.UserSummary;
import com.bhook.identity.client.CampusClient;
import com.bhook.identity.client.CampusDomainLookup;
import com.bhook.identity.domain.OtpChallenge;
import com.bhook.identity.domain.OtpChannel;
import com.bhook.identity.domain.OtpPurpose;
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
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class SignupService {

    private final CampusClient campusClient;
    private final OtpService otpService;
    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final UserSessionRepository userSessionRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;
    private final OutboxWriter outboxWriter;
    private final ObjectMapper objectMapper;
    private final SecureRandom random = new SecureRandom();

    @Transactional
    public EmailChallengeResponse startEmailChallenge(EmailChallengeRequest req) {
        String email = req.email().toLowerCase();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw BhookException.conflict("Email already registered");
        }

        CampusDomainLookup lookup = campusClient.lookupByEmail(email);
        if (lookup == null) {
            throw new BhookException(ErrorCode.INTERNAL_ERROR, HttpStatus.SERVICE_UNAVAILABLE,
                    "Campus service unavailable, try again shortly", true);
        }
        if (lookup.matches().isEmpty()) {
            throw new BhookException(ErrorCode.VALIDATION_FAILED, HttpStatus.BAD_REQUEST,
                    "This email domain is not registered with any campus");
        }

        String metadataJson = writeMetadata(email, lookup);
        UUID challengeId = otpService.issueWithMetadata(OtpChannel.EMAIL, OtpPurpose.SIGNUP, email, metadataJson);

        List<EmailChallengeResponse.CampusMatch> matches = lookup.matches().stream()
                .map(m -> new EmailChallengeResponse.CampusMatch(m.campusId(), m.campusName(), m.membershipType(), m.autoVerify()))
                .toList();
        return new EmailChallengeResponse(challengeId, email, 300, matches);
    }

    @Transactional
    public TokenResponse completeSignup(CompleteSignupRequest req) {
        OtpChallenge challenge = otpService.verify(req.challengeId(), req.otp());
        if (challenge.getPurpose() != OtpPurpose.SIGNUP) {
            throw BhookException.validation("Challenge is not a signup challenge");
        }
        SignupMetadata meta = readMetadata(challenge.getMetadata());
        if (userRepository.existsByEmailIgnoreCase(meta.email())) {
            throw BhookException.conflict("Email already registered");
        }
        if (req.phoneE164() != null && userRepository.existsByPhoneE164(req.phoneE164())) {
            throw BhookException.conflict("Phone already registered");
        }

        SignupMetadata.Match chosen = pickMatch(meta, req.campusId());

        User user = User.builder()
                .email(meta.email())
                .phoneE164(req.phoneE164())
                .passwordHash(passwordEncoder.encode(req.password()))
                .displayName(req.displayName())
                .status(UserStatus.VERIFIED)
                .build();
        user = userRepository.save(user);

        userRoleRepository.save(UserRole.builder()
                .userId(user.getId())
                .roleName(RoleName.CUSTOMER)
                .campusId(chosen.campusId())
                .build());

        outboxWriter.write(
                Topics.IDENTITY_USER_EVENTS,
                "User",
                user.getId().toString(),
                CustomerSignupCompletedEvent.EVENT_TYPE,
                new CustomerSignupCompletedEvent(
                        user.getId(), user.getEmail(), user.getPhoneE164(), user.getDisplayName(),
                        chosen.campusId(), chosen.campusName(), chosen.membershipType(),
                        chosen.autoVerify(), meta.domain(), Instant.now()
                )
        );

        return issueTokens(user, null);
    }

    private SignupMetadata.Match pickMatch(SignupMetadata meta, UUID requestedCampusId) {
        List<SignupMetadata.Match> matches = meta.matches();
        if (requestedCampusId != null) {
            return matches.stream()
                    .filter(m -> requestedCampusId.equals(m.campusId()))
                    .findFirst()
                    .orElseThrow(() -> BhookException.validation("Requested campus is not one of the matches for this email"));
        }
        if (matches.size() == 1) return matches.get(0);
        SignupMetadata.Match autoVerify = matches.stream().filter(SignupMetadata.Match::autoVerify).findFirst().orElse(null);
        if (autoVerify != null) return autoVerify;
        throw new BhookException(ErrorCode.VALIDATION_FAILED, HttpStatus.BAD_REQUEST,
                "Multiple campuses match this email domain — specify campusId");
    }

    private TokenResponse issueTokens(User user, String deviceId) {
        List<UserRole> roles = userRoleRepository.findByUserId(user.getId());
        List<String> roleNames = roles.stream().map(r -> r.getRoleName().name()).distinct().toList();
        String refreshToken = generateRefreshToken();
        UserSession session = userSessionRepository.save(UserSession.builder()
                .userId(user.getId())
                .refreshTokenHash(HashUtils.sha256(refreshToken))
                .deviceId(deviceId)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(jwtProperties.refreshTokenTtlSeconds()))
                .build());
        String accessToken = jwtService.issueAccessToken(user.getId(), session.getId().toString(), roleNames, List.of());
        return new TokenResponse(
                accessToken, refreshToken, jwtProperties.accessTokenTtlSeconds(),
                new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getStatus().name(), roleNames)
        );
    }

    private String generateRefreshToken() {
        byte[] bytes = new byte[48];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String writeMetadata(String email, CampusDomainLookup lookup) {
        try {
            ObjectNode root = objectMapper.createObjectNode();
            root.put("email", email);
            root.put("domain", lookup.domain());
            var arr = root.putArray("matches");
            for (CampusDomainLookup.Match m : lookup.matches()) {
                ObjectNode n = arr.addObject();
                n.put("campusId", m.campusId().toString());
                n.put("campusName", m.campusName());
                n.put("membershipType", m.membershipType());
                n.put("autoVerify", m.autoVerify());
            }
            return objectMapper.writeValueAsString(root);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize signup metadata", e);
        }
    }

    private SignupMetadata readMetadata(String json) {
        try {
            return objectMapper.readValue(Objects.requireNonNullElse(json, "{}"), SignupMetadata.class);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to read signup metadata", e);
        }
    }

    public record SignupMetadata(String email, String domain, List<Match> matches) {
        public record Match(UUID campusId, String campusName, String membershipType, boolean autoVerify) {}
    }
}
