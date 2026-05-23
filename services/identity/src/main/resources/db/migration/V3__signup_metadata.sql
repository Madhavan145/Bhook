-- V3__signup_metadata.sql — carry campus context on OTP challenges

ALTER TABLE identity.otp_challenges
    ADD COLUMN metadata JSONB;

CREATE INDEX ix_otp_purpose ON identity.otp_challenges (purpose);
