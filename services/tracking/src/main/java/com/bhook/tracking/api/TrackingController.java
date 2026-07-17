package com.bhook.tracking.api;

import com.bhook.common.error.BhookException;
import com.bhook.common.security.AuthContext;
import com.bhook.tracking.model.OrderTrackingState;
import com.bhook.tracking.model.PartnerLocation;
import com.bhook.tracking.service.TrackingBroadcaster;
import com.bhook.tracking.service.TrackingStore;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class TrackingController {

    private final TrackingStore store;
    private final TrackingBroadcaster broadcaster;

    @PostMapping("/delivery/location")
    public PartnerLocation reportLocation(@Valid @RequestBody LocationReport req) {
        UUID partnerId = req.partnerId();
        AuthContext.requireUserId();
        PartnerLocation loc = new PartnerLocation(
                partnerId, req.latitude(), req.longitude(),
                req.heading(), req.speedMps(), Instant.now()
        );
        OrderTrackingState updated = store.mergeLocation(partnerId, loc);
        if (updated != null) {
            broadcaster.broadcast(updated.orderId(), updated);
        }
        return updated != null ? updated.lastLocation() : loc;
    }

    @GetMapping("/tracking/orders/{orderId}")
    public OrderTrackingState orderState(@PathVariable UUID orderId) {
        AuthContext.requireUserId();
        return store.readOrderState(orderId)
                .orElseThrow(() -> BhookException.notFound("No tracking state for this order yet"));
    }

    public record LocationReport(
            @NotNull UUID partnerId,
            @NotNull BigDecimal latitude,
            @NotNull BigDecimal longitude,
            Double heading,
            Double speedMps
    ) {}
}
