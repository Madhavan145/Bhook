-- V1__init.sql — Campus schema baseline

CREATE SCHEMA IF NOT EXISTS campus;

CREATE TABLE campus.campuses (
    id                       UUID PRIMARY KEY,
    name                     VARCHAR(128) NOT NULL,
    display_name             VARCHAR(128) NOT NULL,
    country                  VARCHAR(64)  NOT NULL,
    region                   VARCHAR(128),
    timezone                 VARCHAR(64)  NOT NULL,
    currency                 VARCHAR(8)   NOT NULL,
    latitude                 DECIMAL(9,6),
    longitude                DECIMAL(9,6),
    status                   VARCHAR(32)  NOT NULL,
    delivery_enabled         BOOLEAN      NOT NULL DEFAULT TRUE,
    hostel_pickup_enabled    BOOLEAN      NOT NULL DEFAULT TRUE,
    partner_access_enabled   BOOLEAN      NOT NULL DEFAULT TRUE,
    boundary_metadata        JSONB,
    verification_config      JSONB,
    delivery_config          JSONB,
    version                  INTEGER      NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ  NOT NULL,
    updated_at               TIMESTAMPTZ  NOT NULL
);

CREATE UNIQUE INDEX ux_campus_name ON campus.campuses (LOWER(name));
CREATE INDEX ix_campus_status ON campus.campuses (status);

CREATE TABLE campus.campus_locations (
    id                UUID PRIMARY KEY,
    campus_id         UUID         NOT NULL REFERENCES campus.campuses(id) ON DELETE CASCADE,
    name              VARCHAR(150) NOT NULL,
    location_type     VARCHAR(32)  NOT NULL,
    parent_id         UUID,
    latitude          DECIMAL(9,6),
    longitude         DECIMAL(9,6),
    instructions      TEXT,
    operating_hours   JSONB,
    status            VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at        TIMESTAMPTZ  NOT NULL,
    updated_at        TIMESTAMPTZ  NOT NULL
);

CREATE INDEX ix_campus_loc_campus ON campus.campus_locations (campus_id);
CREATE INDEX ix_campus_loc_type ON campus.campus_locations (campus_id, location_type);
