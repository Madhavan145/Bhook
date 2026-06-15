package com.bhook.order.api;

import com.bhook.common.security.AuthContext;
import com.bhook.order.api.dto.CancelOrderRequest;
import com.bhook.order.api.dto.CreateOrderRequest;
import com.bhook.order.api.dto.OrderResponse;
import com.bhook.order.api.dto.QuoteRequest;
import com.bhook.order.api.dto.QuoteResponse;
import com.bhook.order.service.OrderService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @PostMapping("/quote")
    public QuoteResponse quote(@Valid @RequestBody QuoteRequest req, HttpServletRequest http) {
        AuthContext.requireUserId();
        return orderService.quote(extractBearer(http), req.vendorId(), req.cartVersion());
    }

    @PostMapping
    public ResponseEntity<OrderResponse> create(@RequestHeader(value = "Idempotency-Key", required = false) String idem,
                                                @Valid @RequestBody CreateOrderRequest req,
                                                HttpServletRequest http) {
        AuthContext.requireUserId();
        return ResponseEntity.status(201).body(orderService.create(extractBearer(http), idem, req));
    }

    @GetMapping
    public List<OrderResponse> list() {
        return orderService.listForUser(AuthContext.requireUserId());
    }

    @GetMapping("/{orderId}")
    public OrderResponse get(@PathVariable UUID orderId) {
        return orderService.get(AuthContext.requireUserId(), orderId);
    }

    @PostMapping("/{orderId}/cancel")
    public OrderResponse cancel(@PathVariable UUID orderId, @Valid @RequestBody CancelOrderRequest req) {
        return orderService.cancel(AuthContext.requireUserId(), orderId, req.reason());
    }

    private String extractBearer(HttpServletRequest req) {
        String h = req.getHeader("Authorization");
        return (h != null && h.startsWith("Bearer ")) ? h.substring(7) : "";
    }
}
