package com.bhook.common.security;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "bhook.security.jwt")
public record JwtProperties(
        String issuer,
        String audience,
        String secret,
        long accessTokenTtlSeconds,
        long refreshTokenTtlSeconds
) {}
