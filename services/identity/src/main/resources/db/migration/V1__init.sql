-- V1__init.sql — Identity schema baseline

CREATE SCHEMA IF NOT EXISTS identity;

CREATE TABLE identity.users (
    id             UUID PRIMARY KEY,
    email          VARCHAR(255) NOT NULL,
    phone_e164     VARCHAR(32),
    password_hash  VARCHAR(255) NOT NULL,
    display_name   VARCHAR(120),
    status         VARCHAR(32)  NOT NULL DEFAULT 'REGISTERED',
    version        INTEGER      NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL,
    deleted_at     TIMESTAMPTZ
);

CREATE UNIQUE INDEX ux_users_email ON identity.users (LOWER(email));
CREATE UNIQUE INDEX ux_users_phone ON identity.users (phone_e164) WHERE phone_e164 IS NOT NULL;
CREATE INDEX ix_users_status ON identity.users (status);

CREATE TABLE identity.user_roles (
    id          UUID PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    role_name   VARCHAR(64) NOT NULL,
    campus_id   UUID,
    vendor_id   UUID,
    created_at  TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX ux_user_roles_unique
    ON identity.user_roles (user_id, role_name, COALESCE(campus_id, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(vendor_id, '00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX ix_user_roles_user ON identity.user_roles (user_id);

CREATE TABLE identity.user_sessions (
    id                  UUID PRIMARY KEY,
    user_id             UUID         NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    refresh_token_hash  VARCHAR(255) NOT NULL,
    device_id           VARCHAR(128),
    issued_at           TIMESTAMPTZ  NOT NULL,
    expires_at          TIMESTAMPTZ  NOT NULL,
    revoked_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX ux_sessions_refresh_hash ON identity.user_sessions (refresh_token_hash);
CREATE INDEX ix_sessions_user ON identity.user_sessions (user_id);
CREATE INDEX ix_sessions_active ON identity.user_sessions (user_id) WHERE revoked_at IS NULL;
