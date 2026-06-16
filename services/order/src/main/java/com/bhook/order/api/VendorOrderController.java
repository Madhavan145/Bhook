package com.bhook.order.api;

import com.bhook.common.security.AuthContext;
import com.bhook.order.api.dto.CancelOrderRequest;
import com.bhook.order.api.dto.OrderResponse;
import com.bhook.order.api.dto.VendorAnalyticsResponse;
import com.bhook.order.service.VendorOrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/vendor/orders")
@RequiredArgsConstructor
public class VendorOrderController {

    private final VendorOrderService vendorOrderService;

    @GetMapping
    public List<OrderResponse> queue(@RequestParam UUID vendorId) {
        AuthContext.requireUserId();
        return vendorOrderService.queue(vendorId);
    }

    @GetMapping("/history")
    public List<OrderResponse> history(
            @RequestParam UUID vendorId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        AuthContext.requireUserId();
        return vendorOrderService.history(vendorId, from, to);
    }

    @GetMapping("/analytics")
    public VendorAnalyticsResponse analytics(
            @RequestParam UUID vendorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        AuthContext.requireUserId();
        return vendorOrderService.analytics(vendorId, from, to);
    }

    @PostMapping("/{orderId}/accept")
    public OrderResponse accept(@RequestParam UUID vendorId, @PathVariable UUID orderId) {
        return vendorOrderService.accept(vendorId, AuthContext.requireUserId(), orderId);
    }

    @PostMapping("/{orderId}/reject")
    public OrderResponse reject(@RequestParam UUID vendorId, @PathVariable UUID orderId,
                                @Valid @RequestBody CancelOrderRequest body) {
        return vendorOrderService.reject(vendorId, AuthContext.requireUserId(), orderId, body.reason());
    }

    @PostMapping("/{orderId}/cancel")
    public OrderResponse cancelAfterAccept(@RequestParam UUID vendorId, @PathVariable UUID orderId,
                                           @Valid @RequestBody CancelOrderRequest body) {
        return vendorOrderService.cancelAfterAccept(vendorId, AuthContext.requireUserId(), orderId, body.reason());
    }

    @PostMapping("/{orderId}/prepare")
    public OrderResponse prepare(@RequestParam UUID vendorId, @PathVariable UUID orderId) {
        return vendorOrderService.markPreparing(vendorId, AuthContext.requireUserId(), orderId);
    }

    @PostMapping("/{orderId}/ready")
    public OrderResponse ready(@RequestParam UUID vendorId, @PathVariable UUID orderId) {
        return vendorOrderService.markReady(vendorId, AuthContext.requireUserId(), orderId);
    }
}
