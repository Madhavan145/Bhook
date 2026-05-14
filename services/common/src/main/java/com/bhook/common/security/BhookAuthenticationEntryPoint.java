package com.bhook.common.security;

import com.bhook.common.error.ApiError;
import com.bhook.common.error.ErrorCode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Missing/expired/invalid tokens must return 401 so clients can trigger a refresh.
 * Without this, Spring Security's default fallback entry point returns 403.
 */
@Component
@RequiredArgsConstructor
public class BhookAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException authException)
            throws java.io.IOException {
        ApiError body = ApiError.builder()
                .type("https://api.bhook.app/errors/" + ErrorCode.UNAUTHORIZED.name())
                .code(ErrorCode.UNAUTHORIZED.name())
                .message("Authentication is required or the session has expired")
                .status(HttpStatus.UNAUTHORIZED.value())
                .correlationId(UUID.randomUUID().toString())
                .retryable(false)
                .build();
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }
}
