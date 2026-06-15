package com.bhook.order.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public record VendorAnalyticsResponse(
        Instant from,
        Instant to,
        String currency,
        long totalOrders,
        long grossRevenueMinor,
        long netRevenueMinor,
        long avgOrderValueMinor,
        long itemsSold,
        Map<String, Long> ordersByStatus,
        List<DailyPoint> daily,
        List<ItemStat> topItems
) {
    public record DailyPoint(String date, long orders, long revenueMinor) {}

    public record ItemStat(UUID itemId, String itemName, long quantity, long revenueMinor, long orders) {}
}
