-- Bhook database bootstrap
-- Creates per-service databases so each service owns its schema in isolation.

CREATE DATABASE bhook_identity     OWNER bhook_user;
CREATE DATABASE bhook_customer     OWNER bhook_user;
CREATE DATABASE bhook_campus       OWNER bhook_user;
CREATE DATABASE bhook_catalog      OWNER bhook_user;
CREATE DATABASE bhook_order        OWNER bhook_user;
CREATE DATABASE bhook_payment      OWNER bhook_user;
CREATE DATABASE bhook_delivery     OWNER bhook_user;
CREATE DATABASE bhook_tracking     OWNER bhook_user;
CREATE DATABASE bhook_social       OWNER bhook_user;
CREATE DATABASE bhook_notification OWNER bhook_user;
CREATE DATABASE bhook_operations   OWNER bhook_user;
CREATE DATABASE bhook_financial    OWNER bhook_user;
CREATE DATABASE bhook_upload       OWNER bhook_user;
