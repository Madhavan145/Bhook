package com.bhook.order.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "orders", schema = "ordering")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderEntity {

    @Id
    @UuidGenerator
    private UUID id;

    @Column(name = "order_number", nullable = false, length = 64, unique = true)
    private String orderNumber;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "campus_id", nullable = false)
    private UUID campusId;

    @Column(name = "vendor_id", nullable = false)
    private UUID vendorId;

    @Column(name = "pickup_location_id")
    private UUID pickupLocationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "fulfillment_mode", nullable = false, length = 32)
    @Builder.Default
    private FulfillmentMode fulfillmentMode = FulfillmentMode.DELIVERY;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private OrderStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_state", nullable = false, length = 32)
    private PaymentState paymentState;

    @Column(nullable = false, length = 8)
    private String currency;

    @Column(name = "subtotal_minor", nullable = false)
    private long subtotalMinor;

    @Column(name = "tax_minor", nullable = false)
    private long taxMinor;

    @Column(name = "delivery_fee_minor", nullable = false)
    private long deliveryFeeMinor;

    @Column(name = "platform_fee_minor", nullable = false)
    private long platformFeeMinor;

    @Column(name = "discount_minor", nullable = false)
    private long discountMinor;

    @Column(name = "total_minor", nullable = false)
    private long totalMinor;

    @Column(name = "payment_method", length = 32)
    private String paymentMethod;

    @Column(name = "client_reference", length = 128)
    private String clientReference;

    @Column(name = "auto_accept", nullable = false)
    private boolean autoAccept;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Version
    @Column(nullable = false)
    private Integer version;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
