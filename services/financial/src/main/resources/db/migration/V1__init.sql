-- V1__init.sql — Financial schema

CREATE SCHEMA IF NOT EXISTS financial;

CREATE TABLE financial.order_totals (
    order_id            UUID PRIMARY KEY,
    vendor_id           UUID         NOT NULL,
    campus_id           UUID         NOT NULL,
    user_id             UUID         NOT NULL,
    currency            VARCHAR(8)   NOT NULL,
    total_minor         BIGINT       NOT NULL,
    subtotal_minor      BIGINT,
    tax_minor           BIGINT,
    delivery_fee_minor  BIGINT,
    platform_fee_minor  BIGINT,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL,
    updated_at          TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_order_totals_vendor ON financial.order_totals (vendor_id);
CREATE INDEX ix_order_totals_completed ON financial.order_totals (vendor_id, completed_at)
    WHERE completed_at IS NOT NULL;

CREATE TABLE financial.ledger_entries (
    id             UUID PRIMARY KEY,
    order_id       UUID         NOT NULL,
    vendor_id      UUID,
    entry_type     VARCHAR(64)  NOT NULL,
    currency       VARCHAR(8)   NOT NULL,
    amount_minor   BIGINT       NOT NULL,
    notes          TEXT,
    created_at     TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_ledger_order_type UNIQUE (order_id, entry_type)
);

CREATE INDEX ix_ledger_vendor ON financial.ledger_entries (vendor_id) WHERE vendor_id IS NOT NULL;
CREATE INDEX ix_ledger_type ON financial.ledger_entries (entry_type);
