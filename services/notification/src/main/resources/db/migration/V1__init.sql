-- V1__init.sql — Notification schema baseline

CREATE SCHEMA IF NOT EXISTS notification;

CREATE TABLE notification.notifications (
    id            UUID PRIMARY KEY,
    user_id       UUID         NOT NULL,
    type          VARCHAR(64)  NOT NULL,
    entity_type   VARCHAR(64),
    entity_id     UUID,
    payload       JSONB        NOT NULL,
    read_at       TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_notifications_user ON notification.notifications (user_id, created_at DESC);

CREATE TABLE notification.device_registrations (
    id             UUID PRIMARY KEY,
    user_id        UUID         NOT NULL,
    device_id      VARCHAR(128) NOT NULL,
    platform       VARCHAR(16)  NOT NULL,
    push_token     VARCHAR(512) NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_devices UNIQUE (user_id, device_id)
);

CREATE INDEX ix_devices_user ON notification.device_registrations (user_id);
