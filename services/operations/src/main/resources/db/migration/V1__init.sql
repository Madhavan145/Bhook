-- V1__init.sql — Operations schema

CREATE SCHEMA IF NOT EXISTS operations;

CREATE TABLE operations.audit_log (
    id                UUID PRIMARY KEY,
    event_type        VARCHAR(128) NOT NULL,
    aggregate_type    VARCHAR(64)  NOT NULL,
    aggregate_id      VARCHAR(64)  NOT NULL,
    actor_user_id     UUID,
    actor_type        VARCHAR(32),
    payload           JSONB        NOT NULL,
    topic             VARCHAR(128) NOT NULL,
    created_at        TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_audit_created ON operations.audit_log (created_at DESC);
CREATE INDEX ix_audit_type    ON operations.audit_log (event_type);
CREATE INDEX ix_audit_agg     ON operations.audit_log (aggregate_type, aggregate_id);
CREATE INDEX ix_audit_actor   ON operations.audit_log (actor_user_id) WHERE actor_user_id IS NOT NULL;

CREATE TABLE operations.support_tickets (
    id                 UUID PRIMARY KEY,
    opener_user_id     UUID         NOT NULL,
    category           VARCHAR(32)  NOT NULL,
    subject            VARCHAR(200) NOT NULL,
    body               TEXT         NOT NULL,
    status             VARCHAR(32)  NOT NULL DEFAULT 'OPEN',
    assigned_to        UUID,
    related_order_id   UUID,
    related_vendor_id  UUID,
    resolution_notes   TEXT,
    created_at         TIMESTAMPTZ  NOT NULL,
    updated_at         TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_tickets_opener ON operations.support_tickets (opener_user_id);
CREATE INDEX ix_tickets_status ON operations.support_tickets (status);
CREATE INDEX ix_tickets_assigned ON operations.support_tickets (assigned_to) WHERE assigned_to IS NOT NULL;
