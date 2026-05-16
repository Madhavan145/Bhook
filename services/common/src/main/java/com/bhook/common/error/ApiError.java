package com.bhook.common.error;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;

import java.util.List;
import java.util.Map;

@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiError(
        String type,
        String code,
        String message,
        int status,
        String correlationId,
        List<FieldError> fieldErrors,
        boolean retryable,
        Map<String, Object> details
) {
    @Builder
    public record FieldError(String field, String code, String message) {}
}
