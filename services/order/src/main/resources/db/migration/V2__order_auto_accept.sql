-- V2__order_auto_accept.sql — snapshot vendor auto-accept preference per order

ALTER TABLE ordering.orders
    ADD COLUMN auto_accept BOOLEAN NOT NULL DEFAULT false;
