package com.bhook.identity;

import com.bhook.identity.api.dto.LoginRequest;
import com.bhook.identity.api.dto.RefreshRequest;
import com.bhook.identity.api.dto.RegisterRequest;
import com.bhook.identity.api.dto.TokenResponse;
import com.bhook.identity.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.TestPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Testcontainers
@SpringBootTest
@TestPropertySource(properties = {
        "bhook.outbox.enabled=false",
        "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration",
        "bhook.security.jwt.secret=test-secret-test-secret-test-secret-test-secret-32chars",
        "bhook.security.jwt.access-token-ttl-seconds=900",
        "bhook.security.jwt.refresh-token-ttl-seconds=2592000",
        "bhook.security.jwt.issuer=https://identity.test.bhook.app",
        "bhook.security.jwt.audience=bhook-api"
})
class AuthFlowIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("bhook_identity")
            .withUsername("bhook_user")
            .withPassword("bhook_pass");

    @Autowired AuthService authService;

    @Test
    void registerLoginRefreshRotates() {
        RegisterRequest reg = new RegisterRequest(
                "asha@example.com", "+919876543210", "correct-horse-battery",
                "Asha", "CUSTOMER"
        );
        TokenResponse registered = authService.register(reg);
        assertThat(registered.accessToken()).isNotBlank();
        assertThat(registered.refreshToken()).isNotBlank();

        TokenResponse loggedIn = authService.login(new LoginRequest("asha@example.com", "correct-horse-battery", null));
        assertThat(loggedIn.refreshToken()).isNotEqualTo(registered.refreshToken());

        TokenResponse refreshed = authService.refresh(new RefreshRequest(loggedIn.refreshToken()));
        assertThat(refreshed.refreshToken()).isNotEqualTo(loggedIn.refreshToken());

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest(loggedIn.refreshToken())))
                .hasMessageContaining("expired or revoked");
    }
}
