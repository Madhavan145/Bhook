package com.bhook.common.error;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.List;
import java.util.UUID;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BhookException.class)
    public ResponseEntity<ApiError> handleBhook(BhookException ex, HttpServletRequest req) {
        return ResponseEntity.status(ex.getStatus()).body(build(ex.getCode(), ex.getStatus(), ex.getMessage(), null, ex.isRetryable()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        List<ApiError.FieldError> fieldErrors = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> ApiError.FieldError.builder()
                        .field(fe.getField())
                        .code(fe.getCode())
                        .message(fe.getDefaultMessage())
                        .build())
                .toList();
        return ResponseEntity.badRequest().body(build(ErrorCode.VALIDATION_FAILED, HttpStatus.BAD_REQUEST, "Validation failed", fieldErrors, false));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex) {
        log.error("Unhandled exception", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(build(ErrorCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred", null, true));
    }

    private ApiError build(ErrorCode code, HttpStatus status, String message, List<ApiError.FieldError> fieldErrors, boolean retryable) {
        return ApiError.builder()
                .type("https://api.bhook.app/errors/" + code.name())
                .code(code.name())
                .message(message)
                .status(status.value())
                .correlationId(UUID.randomUUID().toString())
                .fieldErrors(fieldErrors)
                .retryable(retryable)
                .build();
    }
}
