-- V1__init.sql — Vendor Catalog schema baseline

CREATE SCHEMA IF NOT EXISTS catalog;

CREATE TABLE catalog.vendors (
    id                   UUID PRIMARY KEY,
    campus_id            UUID         NOT NULL,
    vendor_type          VARCHAR(32)  NOT NULL DEFAULT 'FOOD',
    legal_name           VARCHAR(255) NOT NULL,
    display_name         VARCHAR(255) NOT NULL,
    description          TEXT,
    contact_email        VARCHAR(255),
    contact_phone        VARCHAR(32),
    lifecycle_status     VARCHAR(32)  NOT NULL,
    commission_config    JSONB,
    payment_config       JSONB,
    operating_hours      JSONB,
    logo_object_key      VARCHAR(512),
    cover_object_key     VARCHAR(512),
    version              INTEGER      NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ  NOT NULL,
    updated_at           TIMESTAMPTZ  NOT NULL,
    deleted_at           TIMESTAMPTZ
);

CREATE INDEX ix_vendors_campus ON catalog.vendors (campus_id);
CREATE INDEX ix_vendors_status ON catalog.vendors (lifecycle_status);
CREATE INDEX ix_vendors_active_campus ON catalog.vendors (campus_id) WHERE lifecycle_status = 'ACTIVE';
CREATE UNIQUE INDEX ux_vendors_display_name_per_campus ON catalog.vendors (campus_id, LOWER(display_name)) WHERE deleted_at IS NULL;

CREATE TABLE catalog.vendor_memberships (
    id            UUID PRIMARY KEY,
    vendor_id     UUID         NOT NULL REFERENCES catalog.vendors(id) ON DELETE CASCADE,
    user_id       UUID         NOT NULL,
    role          VARCHAR(32)  NOT NULL,
    campus_id     UUID         NOT NULL,
    status        VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    permissions   JSONB,
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_vendor_user UNIQUE (vendor_id, user_id)
);

CREATE INDEX ix_vm_user   ON catalog.vendor_memberships (user_id);
CREATE INDEX ix_vm_vendor ON catalog.vendor_memberships (vendor_id);

CREATE TABLE catalog.menus (
    id           UUID PRIMARY KEY,
    vendor_id    UUID         NOT NULL REFERENCES catalog.vendors(id) ON DELETE CASCADE,
    name         VARCHAR(120) NOT NULL,
    status       VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    version      INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_menus_vendor ON catalog.menus (vendor_id);

CREATE TABLE catalog.categories (
    id             UUID PRIMARY KEY,
    menu_id        UUID         NOT NULL REFERENCES catalog.menus(id) ON DELETE CASCADE,
    vendor_id      UUID         NOT NULL,
    name           VARCHAR(120) NOT NULL,
    display_order  INTEGER      NOT NULL DEFAULT 0,
    status         VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    version        INTEGER      NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_categories_menu   ON catalog.categories (menu_id);
CREATE INDEX ix_categories_vendor ON catalog.categories (vendor_id);

CREATE TABLE catalog.catalog_items (
    id                 UUID PRIMARY KEY,
    vendor_id          UUID         NOT NULL,
    category_id        UUID         NOT NULL REFERENCES catalog.categories(id) ON DELETE CASCADE,
    name               VARCHAR(200) NOT NULL,
    description        TEXT,
    price_minor        BIGINT       NOT NULL,
    tax_minor          BIGINT       NOT NULL DEFAULT 0,
    prep_time_minutes  INTEGER,
    image_object_key   VARCHAR(512),
    dietary_tags       JSONB,
    status             VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    is_archived        BOOLEAN      NOT NULL DEFAULT FALSE,
    version            INTEGER      NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT chk_item_price_nonneg CHECK (price_minor >= 0),
    CONSTRAINT chk_item_tax_nonneg   CHECK (tax_minor   >= 0)
);

CREATE INDEX ix_items_vendor       ON catalog.catalog_items (vendor_id);
CREATE INDEX ix_items_category     ON catalog.catalog_items (category_id);
CREATE INDEX ix_items_vendor_status ON catalog.catalog_items (vendor_id, status) WHERE is_archived = FALSE;

CREATE TABLE catalog.item_variants (
    id                 UUID PRIMARY KEY,
    item_id            UUID         NOT NULL REFERENCES catalog.catalog_items(id) ON DELETE CASCADE,
    name               VARCHAR(120) NOT NULL,
    price_delta_minor  BIGINT       NOT NULL DEFAULT 0,
    status             VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_variants_item ON catalog.item_variants (item_id);

CREATE TABLE catalog.item_modifiers (
    id                 UUID PRIMARY KEY,
    item_id            UUID         NOT NULL REFERENCES catalog.catalog_items(id) ON DELETE CASCADE,
    name               VARCHAR(120) NOT NULL,
    price_delta_minor  BIGINT       NOT NULL DEFAULT 0,
    status             VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_modifiers_item ON catalog.item_modifiers (item_id);

CREATE TABLE catalog.catalog_availability (
    id               UUID PRIMARY KEY,
    item_id          UUID         NOT NULL UNIQUE REFERENCES catalog.catalog_items(id) ON DELETE CASCADE,
    is_available     BOOLEAN      NOT NULL DEFAULT TRUE,
    scheduled_from   TIMESTAMPTZ,
    scheduled_to     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL,
    updated_at       TIMESTAMPTZ  NOT NULL
);

CREATE TABLE catalog.outbox_events (
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

CREATE INDEX ix_catalog_outbox_unpublished ON catalog.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_catalog_outbox_aggregate   ON catalog.outbox_events (aggregate_type, aggregate_id);
