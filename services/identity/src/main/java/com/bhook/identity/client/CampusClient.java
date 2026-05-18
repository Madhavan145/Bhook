package com.bhook.identity.client;

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

    public CampusDomainLookup lookupByEmail(String email) {
        try {
            return client.get()
                    .uri(uri -> uri.path("/api/v1/campuses/email-domains/lookup").queryParam("email", email).build())
                    .retrieve()
                    .body(CampusDomainLookup.class);
        } catch (HttpClientErrorException.NotFound e) {
            return new CampusDomainLookup(email, List.of());
        } catch (RestClientException e) {
            log.warn("Campus lookup unavailable during signup: {}", e.toString());
            return null;
        }
    }
}
