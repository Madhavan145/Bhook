package com.bhook.order.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.bhook.common.error.BhookException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.UUID;

@Slf4j
@Component
public class CatalogClient {

    private final RestClient client;

    public CatalogClient(@Value("${bhook.catalog.base-url:http://localhost:8084}") String baseUrl) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public VendorView getVendor(UUID vendorId, String bearerToken) {
        try {
            return client.get()
                    .uri("/api/v1/vendors/{id}", vendorId)
                    .header("Authorization", "Bearer " + bearerToken)
                    .retrieve()
                    .body(VendorView.class);
        } catch (HttpClientErrorException.NotFound e) {
            throw BhookException.notFound("Vendor not available");
        } catch (RestClientException e) {
            log.warn("Catalog getVendor failed: {}", e.toString());
            throw new BhookException(com.bhook.common.error.ErrorCode.INTERNAL_ERROR,
                    HttpStatus.SERVICE_UNAVAILABLE, "Catalog service unavailable", true);
        }
    }

    public CatalogView getCatalog(UUID vendorId, String bearerToken) {
        try {
            return client.get()
                    .uri("/api/v1/vendors/{id}/catalog", vendorId)
                    .header("Authorization", "Bearer " + bearerToken)
                    .retrieve()
                    .body(CatalogView.class);
        } catch (HttpClientErrorException.NotFound e) {
            throw BhookException.notFound("Vendor not available");
        } catch (RestClientException e) {
            log.warn("Catalog getCatalog failed: {}", e.toString());
            throw new BhookException(com.bhook.common.error.ErrorCode.INTERNAL_ERROR,
                    HttpStatus.SERVICE_UNAVAILABLE, "Catalog service unavailable", true);
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class VendorView {
        public UUID id;
        public UUID campusId;
        public String displayName;
        public String lifecycleStatus;
        public boolean autoAcceptOrders;
        public Double commissionPercent;
    }
}
