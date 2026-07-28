package com.bhook.social.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.UUID;

@Component
public class CustomerClient {
    private final RestClient client;

    public CustomerClient(@Value("${bhook.customer.base-url:http://localhost:8082}") String baseUrl) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public CustomerProfile getMe(String bearer) {
        return client.get().uri("/api/v1/customers/me")
                .header("Authorization", "Bearer " + bearer)
                .retrieve().body(CustomerProfile.class);
    }

    public CustomerProfile getByCode(String bearer, String friendCode) {
        return client.get().uri("/api/v1/customers/directory/code/{code}", friendCode)
                .header("Authorization", "Bearer " + bearer)
                .retrieve().body(CustomerProfile.class);
    }

    public record CustomerProfile(
            UUID userId,
            UUID activeCampusId,
            String friendCode,
            String displayName,
            String profileImageObjectKey
    ) {}
}