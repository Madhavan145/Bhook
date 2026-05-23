package com.bhook.identity.config;

import com.bhook.common.error.GlobalExceptionHandler;
import com.bhook.common.security.ResourceServerSecurity;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@Import({GlobalExceptionHandler.class, ResourceServerSecurity.class})
public class SecurityConfig implements ResourceServerSecurity.SecurityPolicy {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Override
    public String[] publicPaths() {
        return new String[]{
                "/api/v1/auth/register",
                "/api/v1/auth/login",
                "/api/v1/auth/refresh",
                "/api/v1/auth/otp/request",
                "/api/v1/auth/otp/verify",
                "/api/v1/auth/signup/email-challenge",
                "/api/v1/auth/signup/complete",
                "/api/v1/auth/password/reset/request",
                "/api/v1/auth/password/reset/confirm",
                "/api/v1/auth/password/reset/otp-request",
                "/api/v1/auth/password/reset/otp-confirm",
                "/actuator/health",
                "/actuator/info",
                "/v3/api-docs/**",
                "/swagger-ui/**"
        };
    }
}
