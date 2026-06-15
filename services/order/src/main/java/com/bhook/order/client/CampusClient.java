package com.bhook.order.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.UUID;

@Slf4j
@Component
public class CampusClient {
    private final RestClient client;

    public CampusClient(@Value("${bhook.campus.base-url:http://localhost:8083}") String baseUrl) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public long platformFeeMinor(UUID campusId) {
        try {
            CampusView campus = client.get().uri("/api/v1/campuses/{id}", campusId).retrieve().body(CampusView.class);
            return campus == null || campus.platformFeeMinor == null ? 1000L : campus.platformFeeMinor;
        } catch (Exception e) {
            log.warn("Campus fee lookup failed for {}: {}", campusId, e.toString());
            return 1000L;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    static class CampusView { public Long platformFeeMinor; }
}