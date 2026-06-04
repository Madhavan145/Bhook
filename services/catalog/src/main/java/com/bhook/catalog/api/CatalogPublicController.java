package com.bhook.catalog.api;

import com.bhook.catalog.api.dto.PublishedCatalog;
import com.bhook.catalog.api.dto.OfferView;
import com.bhook.catalog.api.dto.VendorResponse;
import com.bhook.catalog.service.CatalogReadService;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendors")
@RequiredArgsConstructor
@Validated
public class CatalogPublicController {

    private final CatalogReadService readService;

    @GetMapping
    public List<VendorResponse> listByCampus(@RequestParam @NotNull UUID campusId) {
        return readService.listActiveForCampus(campusId);
    }

    @GetMapping("/offers")
    public List<OfferView> offersByCampus(@RequestParam @NotNull UUID campusId) {
        return readService.listActiveOffers(campusId);
    }

    @GetMapping("/{vendorId}")
    public VendorResponse get(@PathVariable UUID vendorId) {
        return readService.getPublicVendor(vendorId);
    }

    @GetMapping("/{vendorId}/catalog")
    public PublishedCatalog catalog(@PathVariable UUID vendorId) {
        return readService.getPublicCatalog(vendorId);
    }
}
