-- V1__init.sql — Customer schema baseline

CREATE SCHEMA IF NOT EXISTS customer;

CREATE TABLE customer.customer_profiles (
    id                   UUID PRIMARY KEY,
    user_id              UUID         NOT NULL UNIQUE,
    display_name         VARCHAR(120),
    bio                  TEXT,
    profile_image_url    VARCHAR(512),
    active_campus_id     UUID,
    verification_state   VARCHAR(32)  NOT NULL DEFAULT 'PENDING',
    version              INTEGER      NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ  NOT NULL,
    updated_at           TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_cust_profile_active_campus ON customer.customer_profiles (active_campus_id);

CREATE TABLE customer.campus_memberships (
    id                    UUID PRIMARY KEY,
    user_id               UUID         NOT NULL,
    campus_id             UUID         NOT NULL,
    membership_type       VARCHAR(32)  NOT NULL,
    verification_status   VARCHAR(32)  NOT NULL,
    verification_method   VARCHAR(32),
    valid_from            TIMESTAMPTZ  NOT NULL,
    valid_until           TIMESTAMPTZ,
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ  NOT NULL,
    updated_at            TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_membership_user ON customer.campus_memberships (user_id);
CREATE INDEX ix_membership_campus ON customer.campus_memberships (campus_id);
CREATE UNIQUE INDEX ux_membership_user_campus ON customer.campus_memberships (user_id, campus_id);

CREATE TABLE customer.customer_preferences (
    id                     UUID PRIMARY KEY,
    user_id                UUID         NOT NULL UNIQUE,
    notification_enabled   BOOLEAN      NOT NULL DEFAULT TRUE,
    email_opt_in           BOOLEAN      NOT NULL DEFAULT TRUE,
    sms_opt_in             BOOLEAN      NOT NULL DEFAULT TRUE,
    push_opt_in            BOOLEAN      NOT NULL DEFAULT TRUE,
    privacy_level          VARCHAR(32)  NOT NULL DEFAULT 'STANDARD',
    created_at             TIMESTAMPTZ  NOT NULL,
    updated_at             TIMESTAMPTZ  NOT NULL
);
