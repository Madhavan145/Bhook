package com.bhook.common.security;

import com.bhook.common.error.ApiError;
import com.bhook.common.error.ErrorCode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.util.UUID;

/** Authenticated but insufficient permission/role must stay 403, distinct from 401. */
@Component
@RequiredArgsConstructor
public class BhookAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException accessDeniedException)
            throws java.io.IOException {
        ApiError body = ApiError.builder()
                .type("https://api.bhook.app/errors/" + ErrorCode.FORBIDDEN.name())
                .code(ErrorCode.FORBIDDEN.name())
                .message("You do not have permission to perform this action")
                .status(HttpStatus.FORBIDDEN.value())
                .correlationId(UUID.randomUUID().toString())
                .retryable(false)
                .build();
        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }
}
