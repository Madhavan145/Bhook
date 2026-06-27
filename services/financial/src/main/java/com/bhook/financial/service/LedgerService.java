package com.bhook.financial.service;

import com.bhook.financial.domain.LedgerEntry;
import com.bhook.financial.domain.OrderTotals;
import com.bhook.financial.repository.LedgerEntryRepository;
import com.bhook.financial.repository.OrderTotalsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class LedgerService {

    private static final String ENTRY_PAYMENT_RECEIVED = "PAYMENT_RECEIVED";
    private static final String ENTRY_PLATFORM_COMMISSION = "PLATFORM_COMMISSION";
    private static final String ENTRY_VENDOR_PAYABLE = "VENDOR_PAYABLE";
    private static final String ENTRY_DELIVERY_PAYABLE = "DELIVERY_PARTNER_PAYABLE";

    private final OrderTotalsRepository totalsRepository;
    private final LedgerEntryRepository ledgerRepository;

    @Value("${bhook.financial.commission-basis-points:1500}")
    private int commissionBps;

    @Transactional
        public void recordOrderTotals(UUID orderId, UUID vendorId, UUID campusId, UUID userId,
                                                                  String currency, long totalMinor, int commissionBps) {
        totalsRepository.findById(orderId).orElseGet(() ->
                totalsRepository.save(OrderTotals.builder()
                        .orderId(orderId)
                        .vendorId(vendorId)
                        .campusId(campusId)
                        .userId(userId)
                        .currency(currency)
                        .totalMinor(totalMinor)
                        .commissionBps(commissionBps)
                        .build())
        );
    }

    @Transactional
    public void recordPayment(UUID orderId, long amountMinor, String currency) {
        upsertEntry(orderId, null, ENTRY_PAYMENT_RECEIVED, amountMinor, currency,
                "Payment received from provider");
    }

    @Transactional
    public void recordRefund(UUID orderId, long amountMinor, String currency, String reason) {
        upsertEntry(orderId, null, "PAYMENT_REFUNDED", -amountMinor, currency,
                "Refund: " + (reason == null ? "" : reason));
    }

    @Transactional
    public void closeOrderFinancials(UUID orderId) {
        OrderTotals totals = totalsRepository.findById(orderId).orElse(null);
        if (totals == null) {
            log.warn("No cached totals for completed order {}", orderId);
            return;
        }
        if (totals.getCompletedAt() != null) return;

        int appliedCommissionBps = totals.getCommissionBps() <= 0 ? commissionBps : totals.getCommissionBps();
        long commission = totals.getTotalMinor() * appliedCommissionBps / 10_000L;
        long vendorPayable = totals.getTotalMinor() - commission
                - (totals.getDeliveryFeeMinor() == null ? 0L : totals.getDeliveryFeeMinor())
                - (totals.getPlatformFeeMinor() == null ? 0L : totals.getPlatformFeeMinor());
        long deliveryPayable = totals.getDeliveryFeeMinor() == null ? 0L : totals.getDeliveryFeeMinor();
        if (vendorPayable < 0) vendorPayable = 0;

        upsertEntry(orderId, null, ENTRY_PLATFORM_COMMISSION, commission,
                totals.getCurrency(), "Platform commission at " + appliedCommissionBps + " bps");
        upsertEntry(orderId, totals.getVendorId(), ENTRY_VENDOR_PAYABLE, vendorPayable,
                totals.getCurrency(), "Vendor net payable for completed order");
        if (deliveryPayable > 0) {
            upsertEntry(orderId, null, ENTRY_DELIVERY_PAYABLE, deliveryPayable,
                    totals.getCurrency(), "Delivery partner fee");
        }
        totals.setCompletedAt(Instant.now());
        totalsRepository.save(totals);
    }

    private void upsertEntry(UUID orderId, UUID vendorId, String type, long amount, String currency, String notes) {
        ledgerRepository.findByOrderIdAndEntryType(orderId, type).orElseGet(() ->
                ledgerRepository.save(LedgerEntry.builder()
                        .orderId(orderId)
                        .vendorId(vendorId)
                        .entryType(type)
                        .amountMinor(amount)
                        .currency(currency)
                        .notes(notes)
                        .build())
        );
    }
}
