-- V2__refund_hardening.sql — DB-level idempotency for refunds

CREATE UNIQUE INDEX ux_refund_one_success_per_order
    ON payment.refunds (order_id)
    WHERE status = 'SUCCESS';

CREATE INDEX ix_refund_status ON payment.refunds (status);
