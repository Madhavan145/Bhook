package com.bhook.social.api;

import com.bhook.common.security.AuthContext;
import com.bhook.social.domain.OrderShare;
import com.bhook.social.service.OrderShareService;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/social")
@RequiredArgsConstructor
public class OrderShareController {

    private final OrderShareService shareService;

    @PostMapping("/orders/{orderId}/shares")
    public ResponseEntity<OrderShare> share(@PathVariable UUID orderId, @RequestBody ShareRequest req) {
        return ResponseEntity.status(201).body(
                shareService.share(AuthContext.requireUserId(), orderId, req.targetUserId()));
    }

    @PostMapping("/orders/{orderId}/shares/all")
    public List<OrderShare> shareWithFriends(@PathVariable UUID orderId, @RequestBody ShareActivityRequest req) {
        return shareService.shareWithFriends(AuthContext.requireUserId(), orderId,
                new OrderShareService.ShareSnapshot(req.vendorId(), req.vendorName(), req.itemId(),
                        req.itemName(), req.itemImageObjectKey(), req.categoryName()));
    }

    @DeleteMapping("/orders/shares/{shareId}")
    public ResponseEntity<Void> revoke(@PathVariable UUID shareId) {
        shareService.revoke(AuthContext.requireUserId(), shareId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/orders/{orderId}/shares")
    public List<OrderShare> forOrder(@PathVariable UUID orderId) {
        return shareService.forOrder(orderId);
    }

    @GetMapping("/shared-orders")
    public List<OrderShare> sharedWithMe() {
        return shareService.sharedWithMe(AuthContext.requireUserId());
    }

    public record ShareRequest(@NotNull UUID targetUserId) {}
    public record ShareActivityRequest(UUID vendorId, String vendorName, UUID itemId, String itemName,
                                       String itemImageObjectKey, String categoryName) {}
}
