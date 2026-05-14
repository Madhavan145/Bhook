package com.bhook.common.error;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class BhookException extends RuntimeException {
    private final ErrorCode code;
    private final HttpStatus status;
    private final boolean retryable;

    public BhookException(ErrorCode code, HttpStatus status, String message) {
        this(code, status, message, false);
    }

    public BhookException(ErrorCode code, HttpStatus status, String message, boolean retryable) {
        super(message);
        this.code = code;
        this.status = status;
        this.retryable = retryable;
    }

    public static BhookException notFound(String message) {
        return new BhookException(ErrorCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, message);
    }

    public static BhookException conflict(String message) {
        return new BhookException(ErrorCode.RESOURCE_CONFLICT, HttpStatus.CONFLICT, message);
    }

    public static BhookException forbidden(String message) {
        return new BhookException(ErrorCode.FORBIDDEN, HttpStatus.FORBIDDEN, message);
    }

    public static BhookException unauthorized(String message) {
        return new BhookException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, message);
    }

    public static BhookException validation(String message) {
        return new BhookException(ErrorCode.VALIDATION_FAILED, HttpStatus.BAD_REQUEST, message);
    }
}
