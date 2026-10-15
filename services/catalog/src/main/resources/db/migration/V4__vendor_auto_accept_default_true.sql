-- V4__vendor_auto_accept_default_true.sql — auto-accept is the recommended default; manual approve is opt-in

ALTER TABLE catalog.vendors
    ALTER COLUMN auto_accept_orders SET DEFAULT true;

UPDATE catalog.vendors
    SET auto_accept_orders = true
    WHERE auto_accept_orders = false;
