package com.bhook.order.api;

import com.bhook.common.security.AuthContext;
import com.bhook.order.api.dto.CartResponse;
import com.bhook.order.api.dto.PutCartItemRequest;
import com.bhook.order.api.dto.SetCartQuantityRequest;
import com.bhook.order.service.CartService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/cart")
@RequiredArgsConstructor
@Validated
public class CartController {

    private final CartService cartService;

    @GetMapping
    public CartResponse get(@RequestParam @NotNull UUID vendorId, HttpServletRequest req) {
        AuthContext.requireUserId();
        return cartService.get(extractBearer(req), vendorId);
    }

    @PutMapping("/items")
    public CartResponse putItem(@Valid @RequestBody PutCartItemRequest body, HttpServletRequest req) {
        AuthContext.requireUserId();
        return cartService.putItem(extractBearer(req), body);
    }

    @PatchMapping("/items/{lineId}")
    public CartResponse setQuantity(@PathVariable UUID lineId,
                                    @Valid @RequestBody SetCartQuantityRequest body,
                                    HttpServletRequest req) {
        AuthContext.requireUserId();
        return cartService.setLineQuantity(extractBearer(req), body.vendorId(), lineId, body.quantity());
    }

    @DeleteMapping("/items/{lineId}")
    public CartResponse removeLine(@PathVariable UUID lineId,
                                   @RequestParam @NotNull UUID vendorId,
                                   HttpServletRequest req) {
        AuthContext.requireUserId();
        return cartService.removeLine(extractBearer(req), vendorId, lineId);
    }

    @DeleteMapping
    public ResponseEntity<Void> clear(HttpServletRequest req) {
        AuthContext.requireUserId();
        cartService.clear(extractBearer(req));
        return ResponseEntity.noContent().build();
    }

    private String extractBearer(HttpServletRequest req) {
        String h = req.getHeader("Authorization");
        return (h != null && h.startsWith("Bearer ")) ? h.substring(7) : "";
    }
}
