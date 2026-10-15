ALTER TABLE social.order_shares
    ADD COLUMN vendor_id UUID,
    ADD COLUMN vendor_name VARCHAR(160),
    ADD COLUMN item_id UUID,
    ADD COLUMN item_name VARCHAR(200),
    ADD COLUMN item_image_object_key VARCHAR(500),
    ADD COLUMN category_name VARCHAR(160);