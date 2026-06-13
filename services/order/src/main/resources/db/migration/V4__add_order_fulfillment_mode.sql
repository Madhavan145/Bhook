ALTER TABLE ordering.orders
    ADD COLUMN fulfillment_mode VARCHAR(32) NOT NULL DEFAULT 'DELIVERY';
