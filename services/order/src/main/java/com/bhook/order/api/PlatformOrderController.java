package com.bhook.order.api;

import com.bhook.order.api.dto.OrderResponse;
import com.bhook.order.domain.OrderEntity;
import com.bhook.order.domain.OrderStatus;
import com.bhook.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/platform/orders")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS','PLATFORM_FINANCE')")
public class PlatformOrderController {

    private final OrderRepository orders;

    @GetMapping
    public List<OrderResponse> list(@RequestParam(required = false) OrderStatus status,
                                    @RequestParam(required = false) UUID campusId,
                                    @RequestParam(required = false) UUID vendorId,
                                    @RequestParam(required = false) String query) {
        return filtered(status, campusId, vendorId, query).stream()
                .map(this::toResponse)
                .toList();
    }

    @GetMapping("/summary")
    public PlatformOrderSummary summary(@RequestParam(required = false) UUID campusId,
                                        @RequestParam(required = false) UUID vendorId,
                                        @RequestParam(required = false) Instant from,
                                        @RequestParam(required = false) Instant to) {
        List<OrderEntity> list = orders.findAll().stream()
                .filter(o -> campusId == null || campusId.equals(o.getCampusId()))
                .filter(o -> vendorId == null || vendorId.equals(o.getVendorId()))
                .filter(o -> from == null || !o.getCreatedAt().isBefore(from))
                .filter(o -> to == null || o.getCreatedAt().isBefore(to))
                .toList();
        Map<OrderStatus, Long> byStatus = new EnumMap<>(OrderStatus.class);
        list.stream().collect(Collectors.groupingBy(OrderEntity::getStatus, () -> byStatus, Collectors.counting()));
        Map<UUID, Long> byCampus = list.stream().collect(Collectors.groupingBy(OrderEntity::getCampusId, Collectors.counting()));
        Map<UUID, Long> byVendor = list.stream().collect(Collectors.groupingBy(OrderEntity::getVendorId, Collectors.counting()));
        long gross = list.stream().mapToLong(OrderEntity::getTotalMinor).sum();
        long fees = list.stream().mapToLong(OrderEntity::getPlatformFeeMinor).sum();
        return new PlatformOrderSummary(list.size(), gross, fees, byStatus, byCampus, byVendor);
    }

    private List<OrderEntity> filtered(OrderStatus status, UUID campusId, UUID vendorId, String query) {
        return orders.findAll().stream()
                .filter(o -> status == null || status == o.getStatus())
                .filter(o -> campusId == null || campusId.equals(o.getCampusId()))
                .filter(o -> vendorId == null || vendorId.equals(o.getVendorId()))
                .filter(o -> query == null || query.isBlank()
                        || o.getOrderNumber().toLowerCase().contains(query.toLowerCase())
                        || o.getId().toString().equalsIgnoreCase(query))
                .sorted(Comparator.comparing(OrderEntity::getCreatedAt).reversed())
                .toList();
    }

    private OrderResponse toResponse(OrderEntity o) {
        return new OrderResponse(
                o.getId(), o.getOrderNumber(), o.getStatus(), o.getPaymentState(),
                o.getCampusId(), o.getVendorId(), o.getPickupLocationId(), o.getFulfillmentMode(), o.getCurrency(),
                o.getSubtotalMinor(), o.getTaxMinor(), o.getDeliveryFeeMinor(), o.getPlatformFeeMinor(),
                o.getDiscountMinor(), o.getTotalMinor(), o.getPaymentMethod(), o.getClientReference(),
                o.getVersion(), o.getExpiresAt(), o.getCreatedAt(), List.of()
        );
    }

    public record PlatformOrderSummary(long orderCount, long grossMinor, long platformFeeMinor,
                                       Map<OrderStatus, Long> byStatus, Map<UUID, Long> byCampus,
                                       Map<UUID, Long> byVendor) {}
}