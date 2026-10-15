-- V1__init.sql — Payment schema

CREATE SCHEMA IF NOT EXISTS payment;

CREATE TABLE payment.payment_attempts (
    id                  UUID PRIMARY KEY,
    order_id            UUID         NOT NULL,
    provider            VARCHAR(64)  NOT NULL,
    provider_reference  VARCHAR(255),
    amount_minor        BIGINT       NOT NULL,
    currency            VARCHAR(8)   NOT NULL,
    status              VARCHAR(32)  NOT NULL,
    callback_event_id   VARCHAR(255),
    expires_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL,
    updated_at          TIMESTAMPTZ  NOT NULL,
    CONSTRAINT chk_amount_nonneg CHECK (amount_minor >= 0)
);

CREATE INDEX ix_pa_order ON payment.payment_attempts (order_id);
CREATE INDEX ix_pa_status ON payment.payment_attempts (status);
CREATE UNIQUE INDEX ux_pa_provider_ref
    ON payment.payment_attempts (provider, provider_reference)
    WHERE provider_reference IS NOT NULL;
CREATE UNIQUE INDEX ux_pa_callback
    ON payment.payment_attempts (callback_event_id)
    WHERE callback_event_id IS NOT NULL;

CREATE TABLE payment.refunds (
    id                  UUID PRIMARY KEY,
    order_id            UUID         NOT NULL,
    payment_attempt_id  UUID         NOT NULL REFERENCES payment.payment_attempts(id),
    amount_minor        BIGINT       NOT NULL,
    reason              TEXT,
    status              VARCHAR(32)  NOT NULL,
    provider_reference  VARCHAR(255),
    created_at          TIMESTAMPTZ  NOT NULL,
    updated_at          TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_refunds_order ON payment.refunds (order_id);
CREATE INDEX ix_refunds_attempt ON payment.refunds (payment_attempt_id);

CREATE TABLE payment.outbox_events (
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

CREATE INDEX ix_pay_outbox_unpublished ON payment.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_pay_outbox_aggregate   ON payment.outbox_events (aggregate_type, aggregate_id);
