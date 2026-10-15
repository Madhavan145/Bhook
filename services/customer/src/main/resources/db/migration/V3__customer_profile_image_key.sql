-- V3__customer_profile_image_key.sql — explicit MinIO profile image key

ALTER TABLE customer.customer_profiles
    ADD COLUMN profile_image_object_key VARCHAR(512);

CREATE INDEX ix_cust_profile_display_name
    ON customer.customer_profiles (LOWER(display_name));