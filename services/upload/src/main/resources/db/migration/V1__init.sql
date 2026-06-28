-- V1__init.sql — Upload service schema

CREATE SCHEMA IF NOT EXISTS uploads;

CREATE TABLE uploads.uploaded_objects (
    id             UUID PRIMARY KEY,
    user_id        UUID         NOT NULL,
    purpose        VARCHAR(64)  NOT NULL,
    object_key     VARCHAR(512) NOT NULL UNIQUE,
    bucket         VARCHAR(128) NOT NULL,
    content_type   VARCHAR(128) NOT NULL,
    size_bytes     BIGINT       NOT NULL,
    sha256         VARCHAR(128),
    upload_status  VARCHAR(32)  NOT NULL DEFAULT 'PENDING',
    committed_at   TIMESTAMPTZ,
    expires_at     TIMESTAMPTZ  NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL,
    CONSTRAINT chk_upload_size_nonneg CHECK (size_bytes >= 0)
);

CREATE INDEX ix_upload_user ON uploads.uploaded_objects (user_id);
CREATE INDEX ix_upload_status ON uploads.uploaded_objects (upload_status);
CREATE INDEX ix_upload_purpose ON uploads.uploaded_objects (purpose);
