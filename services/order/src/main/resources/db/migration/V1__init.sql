-- V1__init.sql — Order service schema

CREATE SCHEMA IF NOT EXISTS ordering;

CREATE TABLE ordering.carts (
    id           UUID PRIMARY KEY,
    user_id      UUID         NOT NULL,
    campus_id    UUID         NOT NULL,
    vendor_id    UUID         NOT NULL,
    version      INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_cart_user_vendor UNIQUE (user_id, vendor_id)
);

CREATE INDEX ix_carts_user ON ordering.carts (user_id);

CREATE TABLE ordering.cart_items (
    id                UUID PRIMARY KEY,
    cart_id           UUID         NOT NULL REFERENCES ordering.carts(id) ON DELETE CASCADE,
    item_id           UUID         NOT NULL,
    variant_id        UUID,
    modifier_ids      JSONB,
    quantity          INTEGER      NOT NULL CHECK (quantity > 0),
    unit_price_minor  BIGINT       NOT NULL,
    created_at        TIMESTAMPTZ  NOT NULL,
    updated_at        TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_cart_items_cart ON ordering.cart_items (cart_id);

CREATE TABLE ordering.orders (
    id                    UUID PRIMARY KEY,
    order_number          VARCHAR(64)  NOT NULL UNIQUE,
    user_id               UUID         NOT NULL,
    campus_id             UUID         NOT NULL,
    vendor_id             UUID         NOT NULL,
    pickup_location_id    UUID         NOT NULL,
    status                VARCHAR(40)  NOT NULL,
    payment_state         VARCHAR(32)  NOT NULL,
    currency              VARCHAR(8)   NOT NULL,
    subtotal_minor        BIGINT       NOT NULL,
    tax_minor             BIGINT       NOT NULL,
    delivery_fee_minor    BIGINT       NOT NULL,
    platform_fee_minor    BIGINT       NOT NULL,
    discount_minor        BIGINT       NOT NULL DEFAULT 0,
    total_minor           BIGINT       NOT NULL,
    payment_method        VARCHAR(32),
    client_reference      VARCHAR(128),
    expires_at            TIMESTAMPTZ,
    version               INTEGER      NOT NULL DEFAULT 0,
    created_at            TIMESTAMPTZ  NOT NULL,
    updated_at            TIMESTAMPTZ  NOT NULL,
    CONSTRAINT chk_orders_amounts_nonneg CHECK (
        subtotal_minor >= 0 AND tax_minor >= 0 AND delivery_fee_minor >= 0
        AND platform_fee_minor >= 0 AND discount_minor >= 0 AND total_minor >= 0
    )
);

CREATE INDEX ix_orders_user            ON ordering.orders (user_id);
CREATE INDEX ix_orders_vendor          ON ordering.orders (vendor_id);
CREATE INDEX ix_orders_campus_status   ON ordering.orders (campus_id, status);
CREATE INDEX ix_orders_status_created  ON ordering.orders (status, created_at);

CREATE TABLE ordering.order_items (
    id                 UUID PRIMARY KEY,
    order_id           UUID         NOT NULL REFERENCES ordering.orders(id) ON DELETE CASCADE,
    item_id            UUID         NOT NULL,
    item_name          VARCHAR(200) NOT NULL,
    variant_id         UUID,
    variant_name       VARCHAR(120),
    modifiers_snapshot JSONB,
    quantity           INTEGER      NOT NULL,
    unit_price_minor   BIGINT       NOT NULL,
    tax_minor          BIGINT       NOT NULL,
    line_total_minor   BIGINT       NOT NULL,
    created_at         TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_order_items_order ON ordering.order_items (order_id);

CREATE TABLE ordering.order_status_history (
    id           UUID PRIMARY KEY,
    order_id     UUID         NOT NULL REFERENCES ordering.orders(id) ON DELETE CASCADE,
    from_status  VARCHAR(40),
    to_status    VARCHAR(40)  NOT NULL,
    actor_type   VARCHAR(32),
    actor_id     UUID,
    reason       TEXT,
    created_at   TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_status_history_order ON ordering.order_status_history (order_id, created_at);

CREATE TABLE ordering.idempotency_keys (
    key         VARCHAR(128) PRIMARY KEY,
    user_id     UUID         NOT NULL,
    order_id    UUID         NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_idem_user ON ordering.idempotency_keys (user_id);

CREATE TABLE ordering.outbox_events (
    id              UUID PRIMARY KEY,
    aggregate_type  VARCHAR(64)  NOT NULL,
    aggregate_id    VARCHAR(64)  NOT NULL,
    event_type      VARCHAR(128) NOT NULL,
    payload         JSONB        NOT NULL,
    topic           VARCHAR(128) NOT NULL,
    published_at    TIMESTAMPTZ,
    attempts        INTEGER      NOT NULL DEFAULT 0,
    last_error      TEXT,
    created_at      TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_order_outbox_unpublished ON ordering.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_order_outbox_aggregate   ON ordering.outbox_events (aggregate_type, aggregate_id);
