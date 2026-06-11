package com.bhook.catalog.service;

import com.bhook.catalog.api.dto.PublishedCatalog;
import com.bhook.catalog.api.dto.OfferView;
import com.bhook.catalog.api.dto.VendorResponse;
import com.bhook.catalog.domain.*;
import com.bhook.catalog.repository.*;
import com.bhook.common.error.BhookException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CatalogReadService {

    private final VendorRepository vendorRepository;
    private final MenuRepository menuRepository;
    private final CategoryRepository categoryRepository;
    private final CatalogItemRepository itemRepository;
    private final ItemVariantRepository variantRepository;
    private final ItemModifierRepository modifierRepository;
    private final CatalogAvailabilityRepository availabilityRepository;
    private final VendorAccess access;

    @Transactional(readOnly = true)
    public List<VendorResponse> listActiveForCampus(UUID campusId) {
        return vendorRepository.findByCampusIdAndLifecycleStatus(campusId, VendorLifecycleStatus.ACTIVE).stream()
                .map(this::toVendorResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<OfferView> listActiveOffers(UUID campusId) {
        return vendorRepository.findByCampusIdAndLifecycleStatus(campusId, VendorLifecycleStatus.ACTIVE).stream()
                .flatMap(vendor -> itemRepository.findByVendorIdAndArchivedFalseOrderByCreatedAtAsc(vendor.getId()).stream()
                        .filter(item -> "ACTIVE".equals(item.getStatus()))
                        .filter(item -> item.getOfferPriceMinor() != null
                                && item.getOfferEndsAt() != null
                                && item.getOfferEndsAt().isAfter(java.time.Instant.now()))
                        .map(item -> new OfferView(
                                item.getId(), vendor.getId(), vendor.getDisplayName(), item.getName(),
                                item.getDescription(), item.getPriceMinor(), item.getOfferPriceMinor(),
                                item.getOfferEndsAt(), item.getImageObjectKey(), item.getDietaryTags(),
                                availabilityRepository.findByItemId(item.getId())
                                        .map(CatalogAvailability::isAvailable).orElse(true))))
                .filter(OfferView::available)
                .toList();
    }

    @Transactional(readOnly = true)
    public VendorResponse getPublicVendor(UUID vendorId) {
        Vendor v = vendorRepository.findById(vendorId)
                .orElseThrow(() -> BhookException.notFound("Vendor not found"));
        if (v.getLifecycleStatus() != VendorLifecycleStatus.ACTIVE) {
            throw BhookException.notFound("Vendor not available");
        }
        return toVendorResponse(v);
    }

    @Transactional(readOnly = true)
    public PublishedCatalog getPublicCatalog(UUID vendorId) {
        Vendor vendor = vendorRepository.findById(vendorId)
                .orElseThrow(() -> BhookException.notFound("Vendor not found"));
        if (vendor.getLifecycleStatus() != VendorLifecycleStatus.ACTIVE) {
            throw BhookException.notFound("Vendor not available");
        }

        List<Menu> menus = menuRepository.findByVendorIdOrderByCreatedAtAsc(vendorId);
        List<Category> categories = categoryRepository.findByVendorIdOrderByDisplayOrderAsc(vendorId);
        List<CatalogItem> items = itemRepository.findByVendorIdAndArchivedFalseOrderByCreatedAtAsc(vendorId);

        Map<UUID, List<CatalogItem>> itemsByCategory = items.stream()
                .filter(i -> "ACTIVE".equals(i.getStatus()))
                .collect(Collectors.groupingBy(CatalogItem::getCategoryId));

        List<UUID> itemIds = items.stream().map(CatalogItem::getId).toList();
        Map<UUID, List<ItemVariant>> variantsByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream().collect(Collectors.toMap(id -> id, variantRepository::findByItemIdOrderByCreatedAtAsc));
        Map<UUID, List<ItemModifier>> modifiersByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream().collect(Collectors.toMap(id -> id, modifierRepository::findByItemIdOrderByCreatedAtAsc));
        Map<UUID, CatalogAvailability> availByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream()
                        .map(availabilityRepository::findByItemId)
                        .flatMap(java.util.Optional::stream)
                        .collect(Collectors.toMap(CatalogAvailability::getItemId, a -> a));

        Map<UUID, List<Category>> categoriesByMenu = categories.stream()
                .filter(c -> "ACTIVE".equals(c.getStatus()))
                .collect(Collectors.groupingBy(Category::getMenuId));

        List<PublishedCatalog.MenuView> menuViews = menus.stream()
                .filter(m -> "ACTIVE".equals(m.getStatus()))
                .map(m -> new PublishedCatalog.MenuView(
                        m.getId(),
                        m.getName(),
                        categoriesByMenu.getOrDefault(m.getId(), List.of()).stream()
                                .map(c -> new PublishedCatalog.CategoryView(
                                        c.getId(), c.getName(), c.getDisplayOrder(),
                                        itemsByCategory.getOrDefault(c.getId(), List.of()).stream()
                                                .map(i -> toItemView(i, variantsByItem, modifiersByItem, availByItem))
                                                .toList()
                                ))
                                .toList()
                ))
                .toList();

        return new PublishedCatalog(vendor.getId(), vendor.getDisplayName(), vendor.getCampusId(), menuViews);
    }

    @Transactional(readOnly = true)
    public PublishedCatalog getManagedCatalog(UUID vendorId, UUID userId) {
        Vendor vendor = access.requireVendor(vendorId);
        access.requireAnyStaff(vendorId, userId);

        List<Menu> menus = menuRepository.findByVendorIdOrderByCreatedAtAsc(vendorId);
        List<Category> categories = categoryRepository.findByVendorIdOrderByDisplayOrderAsc(vendorId);
        List<CatalogItem> items = itemRepository.findByVendorIdAndArchivedFalseOrderByCreatedAtAsc(vendorId);

        Map<UUID, List<CatalogItem>> itemsByCategory = items.stream()
                .collect(Collectors.groupingBy(CatalogItem::getCategoryId));

        List<UUID> itemIds = items.stream().map(CatalogItem::getId).toList();
        Map<UUID, List<ItemVariant>> variantsByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream().collect(Collectors.toMap(id -> id, variantRepository::findByItemIdOrderByCreatedAtAsc));
        Map<UUID, List<ItemModifier>> modifiersByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream().collect(Collectors.toMap(id -> id, modifierRepository::findByItemIdOrderByCreatedAtAsc));
        Map<UUID, CatalogAvailability> availByItem = itemIds.isEmpty() ? Map.of() :
                itemIds.stream()
                        .map(availabilityRepository::findByItemId)
                        .flatMap(java.util.Optional::stream)
                        .collect(Collectors.toMap(CatalogAvailability::getItemId, a -> a));

        Map<UUID, List<Category>> categoriesByMenu = categories.stream()
                .collect(Collectors.groupingBy(Category::getMenuId));

        List<PublishedCatalog.MenuView> menuViews = menus.stream()
                .map(m -> new PublishedCatalog.MenuView(
                        m.getId(),
                        m.getName(),
                        categoriesByMenu.getOrDefault(m.getId(), List.of()).stream()
                                .map(c -> new PublishedCatalog.CategoryView(
                                        c.getId(), c.getName(), c.getDisplayOrder(),
                                        itemsByCategory.getOrDefault(c.getId(), List.of()).stream()
                                                .map(i -> toItemView(i, variantsByItem, modifiersByItem, availByItem))
                                                .toList()
                                ))
                                .toList()
                ))
                .toList();

        return new PublishedCatalog(vendor.getId(), vendor.getDisplayName(), vendor.getCampusId(), menuViews);
    }

    private PublishedCatalog.ItemView toItemView(CatalogItem i,
                                                 Map<UUID, List<ItemVariant>> variantsByItem,
                                                 Map<UUID, List<ItemModifier>> modifiersByItem,
                                                 Map<UUID, CatalogAvailability> availByItem) {
        boolean available = availByItem.containsKey(i.getId()) ? availByItem.get(i.getId()).isAvailable() : true;
        return new PublishedCatalog.ItemView(
                i.getId(), i.getName(), i.getDescription(),
                i.getPriceMinor(), activeOfferPrice(i), activeOfferEndsAt(i), i.getTaxMinor(),
                i.getPrepTimeMinutes(), i.getImageObjectKey(), i.getDietaryTags(),
                i.getStatus(), available,
                variantsByItem.getOrDefault(i.getId(), List.of()).stream()
                        .map(v -> new PublishedCatalog.VariantView(v.getId(), v.getName(), v.getPriceDeltaMinor()))
                        .toList(),
                modifiersByItem.getOrDefault(i.getId(), List.of()).stream()
                        .map(m -> new PublishedCatalog.ModifierView(m.getId(), m.getName(), m.getPriceDeltaMinor()))
                        .toList()
        );
    }

        private Long activeOfferPrice(CatalogItem item) {
                return item.getOfferPriceMinor() != null && item.getOfferEndsAt() != null
                                && item.getOfferEndsAt().isAfter(java.time.Instant.now())
                                ? item.getOfferPriceMinor() : null;
        }

        private java.time.Instant activeOfferEndsAt(CatalogItem item) {
                return activeOfferPrice(item) == null ? null : item.getOfferEndsAt();
        }

    private VendorResponse toVendorResponse(Vendor v) {
        return new VendorResponse(
                v.getId(), v.getCampusId(), v.getVendorType(),
                v.getLegalName(), v.getDisplayName(), v.getDescription(),
                v.getContactEmail(), v.getContactPhone(), v.getLifecycleStatus(),
                v.getLogoObjectKey(), v.getCoverObjectKey(), v.isAutoAcceptOrders(), null,
                v.getVersion(), v.getCreatedAt(), v.getUpdatedAt()
        );
    }
}
