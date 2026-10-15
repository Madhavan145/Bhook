-- V2__email_domains.sql — Campus email domain allowlist for membership verification

CREATE TABLE campus.campus_email_domains (
    id                UUID PRIMARY KEY,
    campus_id         UUID         NOT NULL REFERENCES campus.campuses(id) ON DELETE CASCADE,
    domain            VARCHAR(255) NOT NULL,
    membership_type   VARCHAR(32)  NOT NULL,
    auto_verify       BOOLEAN      NOT NULL DEFAULT FALSE,
    status            VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    notes             VARCHAR(512),
    created_at        TIMESTAMPTZ  NOT NULL,
    updated_at        TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ux_campus_domain UNIQUE (campus_id, domain)
);

CREATE INDEX ix_email_domain_domain ON campus.campus_email_domains (domain);
CREATE INDEX ix_email_domain_active ON campus.campus_email_domains (campus_id) WHERE status = 'ACTIVE';
