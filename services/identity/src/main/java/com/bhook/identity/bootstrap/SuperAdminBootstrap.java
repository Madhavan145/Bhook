package com.bhook.identity.bootstrap;

import com.bhook.identity.domain.RoleName;
import com.bhook.identity.domain.User;
import com.bhook.identity.domain.UserRole;
import com.bhook.identity.domain.UserStatus;
import com.bhook.identity.repository.UserRepository;
import com.bhook.identity.repository.UserRoleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.Base64;

@Slf4j
@Component
@RequiredArgsConstructor
public class SuperAdminBootstrap {

    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final PasswordEncoder passwordEncoder;
    private final SecureRandom random = new SecureRandom();

    @Value("${bhook.bootstrap.admin-email:}")
    private String adminEmail;

    @Value("${bhook.bootstrap.admin-password:}")
    private String presetPassword;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void run() {
        if (adminEmail == null || adminEmail.isBlank()) {
            log.debug("No BHOOK_BOOTSTRAP_ADMIN_EMAIL configured — skipping super admin bootstrap");
            return;
        }
        if (superAdminExists()) {
            log.debug("A super admin already exists — bootstrap skipped");
            return;
        }
        String normalized = adminEmail.toLowerCase();
        User user = userRepository.findByEmailIgnoreCase(normalized).orElseGet(() -> {
            String password = presetPassword != null && !presetPassword.isBlank()
                    ? presetPassword
                    : generatePassword();
            User u = userRepository.save(User.builder()
                    .email(normalized)
                    .passwordHash(passwordEncoder.encode(password))
                    .displayName("Super Admin")
                    .status(UserStatus.ACTIVE)
                    .build());
            log.warn("========================================================================");
            log.warn("PLATFORM_SUPER_ADMIN bootstrapped: email={} password={}", normalized, password);
            log.warn("This password is only logged once. Rotate immediately in production.");
            log.warn("========================================================================");
            return u;
        });
        userRoleRepository.save(UserRole.builder()
                .userId(user.getId())
                .roleName(RoleName.PLATFORM_SUPER_ADMIN)
                .build());
        log.warn("Granted PLATFORM_SUPER_ADMIN role to user_id={}", user.getId());
    }

    private boolean superAdminExists() {
        return userRoleRepository.existsByRoleName(RoleName.PLATFORM_SUPER_ADMIN);
    }

    private String generatePassword() {
        byte[] bytes = new byte[18];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
