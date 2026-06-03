CREATE TABLE catalog.vendor_invitations (
    id             UUID PRIMARY KEY,
    vendor_id      UUID NOT NULL REFERENCES catalog.vendors(id) ON DELETE CASCADE,
    invited_email  VARCHAR(255),
    token_hash     VARCHAR(64) NOT NULL UNIQUE,
    expires_at     TIMESTAMPTZ NOT NULL,
    accepted_at    TIMESTAMPTZ,
    revoked_at     TIMESTAMPTZ,
    created_by     UUID NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL
);

CREATE INDEX ix_vendor_invites_vendor ON catalog.vendor_invitations (vendor_id);