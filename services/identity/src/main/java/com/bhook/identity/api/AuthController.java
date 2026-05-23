package com.bhook.identity.api;

import com.bhook.common.security.AuthContext;
import com.bhook.identity.api.dto.*;
import com.bhook.identity.domain.OtpChallenge;
import com.bhook.identity.security.RateLimiter;
import com.bhook.identity.service.AuthService;
import com.bhook.identity.service.OtpService;
import com.bhook.identity.service.PasswordResetService;
import com.bhook.identity.service.SignupService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final OtpService otpService;
    private final PasswordResetService passwordResetService;
    private final SignupService signupService;
    private final RateLimiter rateLimiter;

    @PostMapping("/register")
    public ResponseEntity<TokenResponse> register(@Valid @RequestBody RegisterRequest req, HttpServletRequest http) {
        rateLimiter.hit("register:ip:" + clientIp(http), 20, Duration.ofMinutes(10));
        return ResponseEntity.status(201).body(authService.register(req));
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req, HttpServletRequest http) {
        rateLimiter.hit("login:email:" + req.email().toLowerCase(), 10, Duration.ofMinutes(5));
        rateLimiter.hit("login:ip:" + clientIp(http), 30, Duration.ofMinutes(5));
        return authService.login(req);
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest req, HttpServletRequest http) {
        rateLimiter.hit("refresh:ip:" + clientIp(http), 60, Duration.ofMinutes(5));
        return authService.refresh(req);
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        AuthContext.principal().ifPresent(p -> {
            if (p.sessionId() != null) {
                authService.logout(UUID.fromString(p.sessionId()));
            }
        });
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    public UserSummary me() {
        return authService.me(AuthContext.requireUserId());
    }

    @PostMapping("/signup/email-challenge")
    public EmailChallengeResponse startSignup(@Valid @RequestBody EmailChallengeRequest req, HttpServletRequest http) {
        rateLimiter.hit("signup:email:" + req.email().toLowerCase(), 5, Duration.ofHours(1));
        rateLimiter.hit("signup:ip:" + clientIp(http), 30, Duration.ofHours(1));
        return signupService.startEmailChallenge(req);
    }

    @PostMapping("/signup/complete")
    public ResponseEntity<TokenResponse> completeSignup(@Valid @RequestBody CompleteSignupRequest req) {
        return ResponseEntity.status(201).body(signupService.completeSignup(req));
    }

    @PostMapping("/otp/request")
    public OtpChallengeResponse otpRequest(@Valid @RequestBody OtpRequest req, HttpServletRequest http) {
        rateLimiter.hit("otp:dest:" + req.destination().toLowerCase(), 5, Duration.ofHours(1));
        rateLimiter.hit("otp:ip:" + clientIp(http), 30, Duration.ofHours(1));
        UUID id = otpService.issue(req.channel(), req.purpose(), req.destination());
        return new OtpChallengeResponse(id, 300);
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<Void> otpVerify(@Valid @RequestBody OtpVerifyRequest req) {
        OtpChallenge verified = otpService.verify(req.challengeId(), req.code());
        return verified != null ? ResponseEntity.noContent().build() : ResponseEntity.badRequest().build();
    }

    @PostMapping("/password/reset/request")
    public ResponseEntity<Void> passwordResetRequest(@Valid @RequestBody PasswordResetRequest req, HttpServletRequest http) {
        rateLimiter.hit("pwreset:email:" + req.email().toLowerCase(), 5, Duration.ofHours(1));
        rateLimiter.hit("pwreset:ip:" + clientIp(http), 20, Duration.ofHours(1));
        passwordResetService.requestReset(req.email());
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/password/reset/otp-request")
    public OtpChallengeResponse passwordResetOtpRequest(@Valid @RequestBody PasswordResetRequest req,
                                                         HttpServletRequest http) {
        rateLimiter.hit("pwreset:email:" + req.email().toLowerCase(), 5, Duration.ofHours(1));
        rateLimiter.hit("pwreset:ip:" + clientIp(http), 20, Duration.ofHours(1));
        UUID id = passwordResetService.requestOtpReset(req.email());
        return new OtpChallengeResponse(id, 300);
    }

    @PostMapping("/password/reset/otp-confirm")
    public ResponseEntity<Void> passwordResetOtpConfirm(
            @Valid @RequestBody PasswordResetOtpConfirm req) {
        passwordResetService.confirmOtpReset(UUID.fromString(req.challengeId()), req.otp(), req.newPassword());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/password/reset/confirm")
    public ResponseEntity<Void> passwordResetConfirm(@Valid @RequestBody PasswordResetConfirm req) {
        passwordResetService.confirm(req.token(), req.newPassword());
        return ResponseEntity.noContent().build();
    }

    private String clientIp(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            int comma = forwarded.indexOf(',');
            return comma > 0 ? forwarded.substring(0, comma).trim() : forwarded.trim();
        }
        return req.getRemoteAddr();
    }
}
