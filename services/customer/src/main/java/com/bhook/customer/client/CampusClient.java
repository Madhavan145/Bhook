package com.bhook.customer.client;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.List;

@Slf4j
@Component
public class CampusClient {

    private final RestClient client;

    public CampusClient(@Value("${bhook.campus.base-url:http://localhost:8083}") String baseUrl) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public CampusDomainLookup lookupByEmail(String email, String bearerToken) {
        try {
            return client.get()
                    .uri(uri -> uri.path("/api/v1/campuses/email-domains/lookup").queryParam("email", email).build())
                    .header("Authorization", "Bearer " + bearerToken)
                    .retrieve()
                    .body(CampusDomainLookup.class);
        } catch (HttpClientErrorException.NotFound e) {
            return new CampusDomainLookup(email, List.of());
        } catch (RestClientException e) {
            log.warn("Campus lookup failed for {}: {}", maskEmail(email), e.toString());
            return new CampusDomainLookup(email, List.of());
        }
    }

    private String maskEmail(String email) {
        if (email == null) return "***";
        int at = email.indexOf('@');
        if (at <= 1) return "***" + email.substring(Math.max(0, at));
        return email.charAt(0) + "***" + email.substring(at);
    }
}
