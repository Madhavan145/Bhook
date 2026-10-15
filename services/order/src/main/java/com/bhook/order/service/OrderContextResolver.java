package com.bhook.order.service;

import com.bhook.order.client.CatalogClient;
import com.bhook.order.client.CatalogView;
import com.bhook.order.client.CustomerClient;
import com.bhook.order.client.CustomerProfileView;
import com.bhook.common.error.BhookException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class OrderContextResolver {

    private final CustomerClient customerClient;
    private final CatalogClient catalogClient;

    public CustomerProfileView requireVerifiedCustomer(String bearer) {
        CustomerProfileView me = customerClient.getMe(bearer);
        if (me == null) throw BhookException.unauthorized("Customer profile unavailable");
        if (me.activeCampusId() == null) {
            throw BhookException.forbidden("No verified active campus. Complete campus verification first.");
        }
        return me;
    }

    public CatalogClient.VendorView requireOrderableVendor(UUID vendorId, UUID expectedCampusId, String bearer) {
        CatalogClient.VendorView v = catalogClient.getVendor(vendorId, bearer);
        if (v == null) throw BhookException.notFound("Vendor not available");
        if (!expectedCampusId.equals(v.campusId)) {
            throw BhookException.forbidden("Vendor does not belong to your active campus");
        }
        if (!"ACTIVE".equals(v.lifecycleStatus)) {
            throw BhookException.notFound("Vendor not available");
        }
        return v;
    }

    public Map<UUID, CatalogView.ItemView> indexItems(CatalogView catalog) {
        Map<UUID, CatalogView.ItemView> byId = new HashMap<>();
        if (catalog == null || catalog.menus() == null) return byId;
        for (CatalogView.MenuView m : catalog.menus()) {
            for (CatalogView.CategoryView c : m.categories()) {
                for (CatalogView.ItemView i : c.items()) {
                    byId.put(i.itemId(), i);
                }
            }
        }
        return byId;
    }
}
