package com.bhook.catalog.api;

import com.bhook.catalog.api.dto.*;
import com.bhook.catalog.domain.*;
import com.bhook.catalog.service.CatalogReadService;
import com.bhook.catalog.service.CatalogWriteService;
import com.bhook.common.security.AuthContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendors/{vendorId}/menu")
@RequiredArgsConstructor
public class CatalogAdminController {

    private final CatalogWriteService writeService;
    private final CatalogReadService readService;

    @GetMapping
    public PublishedCatalog getManagedCatalog(@PathVariable UUID vendorId) {
        return readService.getManagedCatalog(vendorId, AuthContext.requireUserId());
    }

    @PostMapping
    public ResponseEntity<Menu> createMenu(@PathVariable UUID vendorId, @Valid @RequestBody CreateMenuRequest req) {
        return ResponseEntity.status(201).body(writeService.createMenu(vendorId, AuthContext.requireUserId(), req));
    }

    @PatchMapping("/{menuId}")
    public Menu updateMenu(@PathVariable UUID vendorId, @PathVariable UUID menuId,
                           @Valid @RequestBody UpdateMenuRequest req) {
        return writeService.updateMenu(vendorId, menuId, AuthContext.requireUserId(), req);
    }

    @PostMapping("/{menuId}/categories")
    public ResponseEntity<Category> createCategory(@PathVariable UUID vendorId,
                                                   @PathVariable UUID menuId,
                                                   @Valid @RequestBody CreateCategoryRequest req) {
        return ResponseEntity.status(201).body(writeService.createCategory(vendorId, menuId, AuthContext.requireUserId(), req));
    }

    @PatchMapping("/{menuId}/categories/{categoryId}")
    public Category updateCategory(@PathVariable UUID vendorId, @PathVariable UUID menuId,
                                   @PathVariable UUID categoryId,
                                   @Valid @RequestBody UpdateCategoryRequest req) {
        return writeService.updateCategory(vendorId, menuId, categoryId,
                AuthContext.requireUserId(), req);
    }

    @PostMapping("/items")
    public ResponseEntity<CatalogItem> createItem(@PathVariable UUID vendorId, @Valid @RequestBody CreateItemRequest req) {
        return ResponseEntity.status(201).body(writeService.createItem(vendorId, AuthContext.requireUserId(), req));
    }

    @PatchMapping("/items/{itemId}")
    public CatalogItem updateItem(@PathVariable UUID vendorId, @PathVariable UUID itemId, @Valid @RequestBody UpdateItemRequest req) {
        return writeService.updateItem(vendorId, itemId, AuthContext.requireUserId(), req);
    }

    @DeleteMapping("/items/{itemId}")
    public ResponseEntity<Void> archiveItem(@PathVariable UUID vendorId, @PathVariable UUID itemId) {
        writeService.archiveItem(vendorId, itemId, AuthContext.requireUserId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/items/{itemId}/variants")
    public ResponseEntity<ItemVariant> addVariant(@PathVariable UUID vendorId, @PathVariable UUID itemId, @Valid @RequestBody CreateVariantRequest req) {
        return ResponseEntity.status(201).body(writeService.addVariant(vendorId, itemId, AuthContext.requireUserId(), req));
    }

    @PostMapping("/items/{itemId}/modifiers")
    public ResponseEntity<ItemModifier> addModifier(@PathVariable UUID vendorId, @PathVariable UUID itemId, @Valid @RequestBody CreateModifierRequest req) {
        return ResponseEntity.status(201).body(writeService.addModifier(vendorId, itemId, AuthContext.requireUserId(), req));
    }

    @PutMapping("/items/{itemId}/availability")
    public CatalogAvailability setAvailability(@PathVariable UUID vendorId, @PathVariable UUID itemId, @Valid @RequestBody SetAvailabilityRequest req) {
        return writeService.setAvailability(vendorId, itemId, AuthContext.requireUserId(), req);
    }
}
