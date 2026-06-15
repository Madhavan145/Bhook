package com.bhook.order.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.UUID;

@Slf4j
@Component
public class CustomerClient {

    private final RestClient client;

    public CustomerClient(@Value("${bhook.customer.base-url:http://localhost:8082}") String baseUrl) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public CustomerProfileView getMe(String bearerToken) {
        try {
            CustomerProfileResponse resp = client.get()
                    .uri("/api/v1/customers/me")
                    .header("Authorization", "Bearer " + bearerToken)
                    .retrieve()
                    .body(CustomerProfileResponse.class);
            if (resp == null) return null;
            return new CustomerProfileView(resp.userId, resp.activeCampusId, resp.verificationState, resp.email);
        } catch (RestClientException e) {
            log.warn("Customer service call failed: {}", e.toString());
            return null;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class CustomerProfileResponse {
        public UUID userId;
        public UUID activeCampusId;
        public String verificationState;
        public String email;
    }
}
