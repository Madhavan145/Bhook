-- V3__vendor_auto_accept.sql — vendor opt-in to auto-accept incoming paid orders

ALTER TABLE catalog.vendors
    ADD COLUMN auto_accept_orders BOOLEAN NOT NULL DEFAULT false;
