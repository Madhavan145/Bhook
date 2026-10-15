-- V1__init.sql — Delivery schema

CREATE SCHEMA IF NOT EXISTS delivery;

CREATE TABLE delivery.delivery_partners (
    id                    UUID PRIMARY KEY,
    user_id               UUID         NOT NULL UNIQUE,
    campus_id             UUID         NOT NULL,
    status                VARCHAR(32)  NOT NULL,
    availability_status   VARCHAR(32)  NOT NULL DEFAULT 'OFFLINE',
    active_task_count     INTEGER      NOT NULL DEFAULT 0,
    current_latitude      DECIMAL(9,6),
    current_longitude     DECIMAL(9,6),
    created_at            TIMESTAMPTZ  NOT NULL,
    updated_at            TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_partners_campus_status ON delivery.delivery_partners (campus_id, status, availability_status);

CREATE TABLE delivery.delivery_jobs (
    id            UUID PRIMARY KEY,
    order_id      UUID         NOT NULL UNIQUE,
    vendor_id     UUID         NOT NULL,
    campus_id     UUID         NOT NULL,
    partner_id    UUID,
    status        VARCHAR(40)  NOT NULL,
    assigned_at   TIMESTAMPTZ,
    accepted_at   TIMESTAMPTZ,
    pickup_at     TIMESTAMPTZ,
    delivered_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_jobs_partner ON delivery.delivery_jobs (partner_id);
CREATE INDEX ix_jobs_campus_status ON delivery.delivery_jobs (campus_id, status);

CREATE TABLE delivery.outbox_events (
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

CREATE INDEX ix_dlv_outbox_unpublished ON delivery.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_dlv_outbox_aggregate   ON delivery.outbox_events (aggregate_type, aggregate_id);
