ALTER TABLE catalog.catalog_items
    ADD COLUMN offer_price_minor BIGINT,
    ADD COLUMN offer_ends_at TIMESTAMPTZ;

ALTER TABLE catalog.catalog_items
    ADD CONSTRAINT chk_item_offer_price_valid
    CHECK (offer_price_minor IS NULL OR (offer_price_minor >= 0 AND offer_price_minor < price_minor));
