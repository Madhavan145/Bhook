-- V4__customer_friend_code.sql — stable customer reference for friendship requests

ALTER TABLE customer.customer_profiles
    ADD COLUMN friend_code VARCHAR(36);

UPDATE customer.customer_profiles
SET friend_code = user_id::text
WHERE friend_code IS NULL;

ALTER TABLE customer.customer_profiles
    ALTER COLUMN friend_code SET NOT NULL;

CREATE UNIQUE INDEX ux_customer_profile_friend_code
    ON customer.customer_profiles (friend_code);