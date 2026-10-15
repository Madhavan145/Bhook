-- V1__init.sql — Social schema (friendships + per-order shares)

CREATE SCHEMA IF NOT EXISTS social;

-- Friendship rows are stored canonically as (user_a_id, user_b_id) with user_a_id < user_b_id lexicographically.
-- This makes uniqueness enforcement simple: one row per pair regardless of who requested.
CREATE TABLE social.friendships (
    id             UUID PRIMARY KEY,
    user_a_id      UUID         NOT NULL,
    user_b_id      UUID         NOT NULL,
    requested_by   UUID         NOT NULL,
    status         VARCHAR(32)  NOT NULL,
    responded_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_friend_pair UNIQUE (user_a_id, user_b_id),
    CONSTRAINT chk_friend_ordering CHECK (user_a_id < user_b_id),
    CONSTRAINT chk_friend_requested_by CHECK (requested_by = user_a_id OR requested_by = user_b_id)
);

CREATE INDEX ix_friend_user_a ON social.friendships (user_a_id);
CREATE INDEX ix_friend_user_b ON social.friendships (user_b_id);
CREATE INDEX ix_friend_status ON social.friendships (status);

CREATE TABLE social.order_shares (
    id                     UUID PRIMARY KEY,
    order_id               UUID         NOT NULL,
    owner_user_id          UUID         NOT NULL,
    shared_with_user_id    UUID         NOT NULL,
    status                 VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    expires_at             TIMESTAMPTZ,
    created_at             TIMESTAMPTZ  NOT NULL,
    updated_at             TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_share_order_target UNIQUE (order_id, shared_with_user_id)
);

CREATE INDEX ix_share_owner  ON social.order_shares (owner_user_id);
CREATE INDEX ix_share_target ON social.order_shares (shared_with_user_id);
CREATE INDEX ix_share_active ON social.order_shares (shared_with_user_id) WHERE status = 'ACTIVE';
