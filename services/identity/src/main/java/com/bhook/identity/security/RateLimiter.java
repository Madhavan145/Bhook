package com.bhook.identity.security;

import com.bhook.common.error.BhookException;
import com.bhook.common.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;

/**
 * Token-bucket rate limiter backed by Redis via an atomic Lua script.
 * Correctly enforces {@code capacity} requests per {@code window} across
 * every replica of the service — the bucket state lives in Redis, not in-process.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RateLimiter {

    private final StringRedisTemplate redis;
    private final DefaultRedisScript<Long> script = loadScript();

    public void hit(String key, int capacity, Duration window) {
        if (capacity <= 0 || window.isZero() || window.isNegative()) return;

        String redisKey = "ratelimit:" + key;
        long windowMillis = Math.max(1L, window.toMillis());
        double refillPerMs = (double) capacity / windowMillis;
        long now = System.currentTimeMillis();
        long ttl = Math.max(60L, windowMillis / 1000L + 60L);

        Long allowed;
        try {
            allowed = redis.execute(
                    script,
                    List.of(redisKey),
                    String.valueOf(capacity),
                    String.valueOf(refillPerMs),
                    String.valueOf(now),
                    String.valueOf(ttl)
            );
        } catch (Exception e) {
            // Redis outage must not stop authentication traffic; log and fail open.
            log.warn("Rate limiter unavailable for key={}: {}", redisKey, e.toString());
            return;
        }

        if (allowed == null || allowed == 0L) {
            throw new BhookException(ErrorCode.RATE_LIMITED, HttpStatus.TOO_MANY_REQUESTS,
                    "Too many requests. Try again shortly.", true);
        }
    }

    private static DefaultRedisScript<Long> loadScript() {
        DefaultRedisScript<Long> s = new DefaultRedisScript<>();
        s.setLocation(new ClassPathResource("scripts/token-bucket.lua"));
        s.setResultType(Long.class);
        return s;
    }
}
