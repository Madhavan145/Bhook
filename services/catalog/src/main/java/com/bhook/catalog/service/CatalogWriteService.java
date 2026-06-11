package com.bhook.catalog.service;

import com.bhook.catalog.api.dto.*;
import com.bhook.catalog.domain.*;
import com.bhook.catalog.outbox.OutboxWriter;
import com.bhook.catalog.repository.*;
import com.bhook.common.error.BhookException;
import com.bhook.common.events.CatalogItemChangedEvent;
import com.bhook.common.events.Topics;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CatalogWriteService {

    private final VendorAccess access;
    private final MenuRepository menuRepository;
    private final CategoryRepository categoryRepository;
    private final CatalogItemRepository itemRepository;
    private final ItemVariantRepository variantRepository;
    private final ItemModifierRepository modifierRepository;
    private final CatalogAvailabilityRepository availabilityRepository;
    private final OutboxWriter outbox;

    @Transactional
    public Menu createMenu(UUID vendorId, UUID actorUserId, CreateMenuRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        return menuRepository.save(Menu.builder()
                .vendorId(vendorId)
                .name(req.name())
                .status("ACTIVE")
                .build());
    }

    @Transactional
    public Menu updateMenu(UUID vendorId, UUID menuId, UUID actorUserId, UpdateMenuRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        Menu menu = menuRepository.findById(menuId)
                .orElseThrow(() -> BhookException.notFound("Menu not found"));
        if (!menu.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Menu does not belong to this vendor");
        }
        if (req.name() != null) menu.setName(req.name());
        return menuRepository.save(menu);
    }

    @Transactional
    public Category createCategory(UUID vendorId, UUID menuId, UUID actorUserId, CreateCategoryRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        Menu menu = menuRepository.findById(menuId)
                .orElseThrow(() -> BhookException.notFound("Menu not found"));
        if (!menu.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Menu does not belong to this vendor");
        }
        return categoryRepository.save(Category.builder()
                .menuId(menu.getId())
                .vendorId(vendorId)
                .name(req.name())
                .displayOrder(req.displayOrder())
                .status("ACTIVE")
                .build());
    }

    @Transactional
    public Category updateCategory(UUID vendorId, UUID menuId, UUID categoryId,
                                   UUID actorUserId, UpdateCategoryRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        Menu menu = menuRepository.findById(menuId)
                .orElseThrow(() -> BhookException.notFound("Menu not found"));
        if (!menu.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Menu does not belong to this vendor");
        }
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> BhookException.notFound("Category not found"));
        if (!category.getVendorId().equals(vendorId) || !category.getMenuId().equals(menuId)) {
            throw BhookException.forbidden("Category does not belong to this menu");
        }
        if (req.name() != null) category.setName(req.name());
        if (req.displayOrder() != null) category.setDisplayOrder(req.displayOrder());
        return categoryRepository.save(category);
    }

    @Transactional
    public CatalogItem createItem(UUID vendorId, UUID actorUserId, CreateItemRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        validateOffer(req.priceMinor(), req.offerEnabled(), req.offerPriceMinor(), req.offerEndsAt());
        Category category = categoryRepository.findById(req.categoryId())
                .orElseThrow(() -> BhookException.notFound("Category not found"));
        if (!category.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Category does not belong to this vendor");
        }
        CatalogItem item = itemRepository.save(CatalogItem.builder()
                .vendorId(vendorId)
                .categoryId(category.getId())
                .name(req.name())
                .description(req.description())
                .priceMinor(req.priceMinor())
                .offerPriceMinor(Boolean.TRUE.equals(req.offerEnabled()) ? req.offerPriceMinor() : null)
                .offerEndsAt(Boolean.TRUE.equals(req.offerEnabled()) ? req.offerEndsAt() : null)
                .taxMinor(req.taxMinor())
                .prepTimeMinutes(req.prepTimeMinutes())
                .imageObjectKey(req.imageObjectKey())
                .dietaryTags(req.dietaryTags())
                .status("ACTIVE")
                .archived(false)
                .build());
        availabilityRepository.save(CatalogAvailability.builder()
                .itemId(item.getId())
                .available(true)
                .build());
        emitItemChanged(item, "CREATED");
        return item;
    }

    @Transactional
    public CatalogItem updateItem(UUID vendorId, UUID itemId, UUID actorUserId, UpdateItemRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        CatalogItem item = itemRepository.findById(itemId)
                .orElseThrow(() -> BhookException.notFound("Item not found"));
        if (!item.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Item does not belong to this vendor");
        }
        boolean priceChanged = false;
        long effectivePrice = req.priceMinor() == null ? item.getPriceMinor() : req.priceMinor();
        Boolean effectiveOfferEnabled = req.offerEnabled() == null
            ? item.getOfferPriceMinor() != null && item.getOfferEndsAt() != null
            : req.offerEnabled();
        Long effectiveOfferPrice = req.offerEnabled() == null
            ? item.getOfferPriceMinor() : req.offerPriceMinor();
        java.time.Instant effectiveOfferEndsAt = req.offerEnabled() == null
            ? item.getOfferEndsAt() : req.offerEndsAt();
        validateOffer(effectivePrice, effectiveOfferEnabled, effectiveOfferPrice, effectiveOfferEndsAt);
        if (req.name() != null) item.setName(req.name());
        if (req.description() != null) item.setDescription(req.description());
        if (req.priceMinor() != null && req.priceMinor() != item.getPriceMinor()) {
            item.setPriceMinor(req.priceMinor());
            priceChanged = true;
        }
        if (req.offerEnabled() != null) {
            item.setOfferPriceMinor(Boolean.TRUE.equals(req.offerEnabled()) ? req.offerPriceMinor() : null);
            item.setOfferEndsAt(Boolean.TRUE.equals(req.offerEnabled()) ? req.offerEndsAt() : null);
        }
        if (req.taxMinor() != null) item.setTaxMinor(req.taxMinor());
        if (req.prepTimeMinutes() != null) item.setPrepTimeMinutes(req.prepTimeMinutes());
        if (req.imageObjectKey() != null) item.setImageObjectKey(req.imageObjectKey());
        if (req.dietaryTags() != null) item.setDietaryTags(req.dietaryTags());
        if (req.status() != null) item.setStatus(req.status());
        CatalogItem saved = itemRepository.save(item);
        emitItemChanged(saved, priceChanged ? "PRICE_CHANGED" : "UPDATED");
        return saved;
    }

    @Transactional
    public void archiveItem(UUID vendorId, UUID itemId, UUID actorUserId) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        CatalogItem item = itemRepository.findById(itemId)
                .orElseThrow(() -> BhookException.notFound("Item not found"));
        if (!item.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Item does not belong to this vendor");
        }
        item.setArchived(true);
        item.setStatus("ARCHIVED");
        itemRepository.save(item);
        emitItemChanged(item, "ARCHIVED");
    }

    @Transactional
    public ItemVariant addVariant(UUID vendorId, UUID itemId, UUID actorUserId, CreateVariantRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        CatalogItem item = requireOwnedItem(vendorId, itemId);
        return variantRepository.save(ItemVariant.builder()
                .itemId(item.getId())
                .name(req.name())
                .priceDeltaMinor(req.priceDeltaMinor())
                .status("ACTIVE")
                .build());
    }

    @Transactional
    public ItemModifier addModifier(UUID vendorId, UUID itemId, UUID actorUserId, CreateModifierRequest req) {
        access.requireOwnerOrManager(vendorId, actorUserId);
        CatalogItem item = requireOwnedItem(vendorId, itemId);
        return modifierRepository.save(ItemModifier.builder()
                .itemId(item.getId())
                .name(req.name())
                .priceDeltaMinor(req.priceDeltaMinor())
                .status("ACTIVE")
                .build());
    }

    @Transactional
    public CatalogAvailability setAvailability(UUID vendorId, UUID itemId, UUID actorUserId, SetAvailabilityRequest req) {
        access.requireAnyStaff(vendorId, actorUserId);
        CatalogItem item = requireOwnedItem(vendorId, itemId);
        CatalogAvailability a = availabilityRepository.findByItemId(item.getId())
                .orElseGet(() -> CatalogAvailability.builder().itemId(item.getId()).available(true).build());
        a.setAvailable(req.available());
        a.setScheduledFrom(req.scheduledFrom());
        a.setScheduledTo(req.scheduledTo());
        return availabilityRepository.save(a);
    }

    private CatalogItem requireOwnedItem(UUID vendorId, UUID itemId) {
        CatalogItem item = itemRepository.findById(itemId)
                .orElseThrow(() -> BhookException.notFound("Item not found"));
        if (!item.getVendorId().equals(vendorId)) {
            throw BhookException.forbidden("Item does not belong to this vendor");
        }
        return item;
    }

    private void validateOffer(long priceMinor, Boolean offerEnabled, Long offerPriceMinor,
                               java.time.Instant offerEndsAt) {
        if (!Boolean.TRUE.equals(offerEnabled)) return;
        if (offerPriceMinor == null || offerEndsAt == null) {
            throw BhookException.validation("Offer price and end time must be provided together");
        }
        if (offerPriceMinor < 0 || offerPriceMinor >= priceMinor) {
            throw BhookException.validation("Offer price must be below the regular price");
        }
        if (!offerEndsAt.isAfter(java.time.Instant.now())) {
            throw BhookException.validation("Offer end time must be in the future");
        }
    }

    private void emitItemChanged(CatalogItem item, String changeType) {
        outbox.write(
                Topics.CAMPUS_EVENTS,
                "CatalogItem",
                item.getId().toString(),
                CatalogItemChangedEvent.EVENT_TYPE,
                new CatalogItemChangedEvent(
                        item.getId(), item.getVendorId(), item.getCategoryId(),
                        changeType, item.getPriceMinor(), item.getTaxMinor(),
                        item.getStatus(), item.isArchived(), Instant.now()
                )
        );
    }
}
