-- V2__verification_and_outbox.sql — customer verification lifecycle + outbox

ALTER TABLE customer.customer_profiles
    ADD COLUMN email      VARCHAR(255),
    ADD COLUMN phone_e164 VARCHAR(32);

CREATE UNIQUE INDEX ux_cust_profile_email ON customer.customer_profiles (LOWER(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX ux_cust_profile_phone ON customer.customer_profiles (phone_e164) WHERE phone_e164 IS NOT NULL;

CREATE TABLE customer.membership_verifications (
    id                    UUID PRIMARY KEY,
    membership_id         UUID         NOT NULL REFERENCES customer.campus_memberships(id) ON DELETE CASCADE,
    user_id               UUID         NOT NULL,
    campus_id             UUID         NOT NULL,
    submitted_email       VARCHAR(255),
    evidence_object_keys  JSONB,
    domain_match          VARCHAR(255),
    matched_membership    VARCHAR(32),
    auto_verified         BOOLEAN      NOT NULL DEFAULT FALSE,
    status                VARCHAR(32)  NOT NULL,
    review_notes          TEXT,
    reviewed_by           UUID,
    reviewed_at           TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL,
    updated_at            TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_mv_membership ON customer.membership_verifications (membership_id);
CREATE INDEX ix_mv_user       ON customer.membership_verifications (user_id);
CREATE INDEX ix_mv_status     ON customer.membership_verifications (status);

CREATE TABLE customer.outbox_events (
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

CREATE INDEX ix_cust_outbox_unpublished ON customer.outbox_events (created_at) WHERE published_at IS NULL;
CREATE INDEX ix_cust_outbox_aggregate   ON customer.outbox_events (aggregate_type, aggregate_id);
