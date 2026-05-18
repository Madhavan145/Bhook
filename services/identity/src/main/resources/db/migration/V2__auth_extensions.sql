-- V2__auth_extensions.sql — OTP, password reset, outbox

CREATE TABLE identity.otp_challenges (
    id            UUID PRIMARY KEY,
    channel       VARCHAR(16)  NOT NULL,
    purpose       VARCHAR(32)  NOT NULL,
    destination   VARCHAR(255) NOT NULL,
    code_hash     VARCHAR(255) NOT NULL,
    attempts      INTEGER      NOT NULL DEFAULT 0,
    max_attempts  INTEGER      NOT NULL DEFAULT 5,
    expires_at    TIMESTAMPTZ  NOT NULL,
    consumed_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_otp_destination ON identity.otp_challenges (destination);
CREATE INDEX ix_otp_expires ON identity.otp_challenges (expires_at);

CREATE TABLE identity.password_reset_tokens (
    id           UUID PRIMARY KEY,
    user_id      UUID         NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    token_hash   VARCHAR(255) NOT NULL,
    expires_at   TIMESTAMPTZ  NOT NULL,
    consumed_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX ux_reset_token_hash ON identity.password_reset_tokens (token_hash);
CREATE INDEX ix_reset_user ON identity.password_reset_tokens (user_id);

CREATE TABLE identity.outbox_events (
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

CREATE INDEX ix_outbox_unpublished ON identity.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_outbox_aggregate ON identity.outbox_events (aggregate_type, aggregate_id);
