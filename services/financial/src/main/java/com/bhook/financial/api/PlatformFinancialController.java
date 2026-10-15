package com.bhook.financial.api;

import com.bhook.financial.domain.LedgerEntry;
import com.bhook.financial.repository.LedgerEntryRepository;
import com.bhook.financial.repository.OrderTotalsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform/financial")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_FINANCE')")
public class PlatformFinancialController {

    private final LedgerEntryRepository ledgerRepository;
    private final OrderTotalsRepository totalsRepository;

    @GetMapping("/orders/{orderId}/entries")
    public List<LedgerEntry> orderEntries(@PathVariable UUID orderId) {
        return ledgerRepository.findByOrderIdOrderByCreatedAtAsc(orderId);
    }

    @GetMapping("/vendors/{vendorId}/earnings")
    public VendorEarnings vendorEarnings(@PathVariable UUID vendorId) {
        long payable = ledgerRepository.sumForVendorByType(vendorId, "VENDOR_PAYABLE");
        return new VendorEarnings(vendorId, totalsRepository.sumCompletedSales(vendorId),
            totalsRepository.sumCompletedCommission(vendorId), payable);
    }

    @GetMapping("/vendors/{vendorId}/entries")
    public List<LedgerEntry> vendorEntries(@PathVariable UUID vendorId) {
        return ledgerRepository.findByVendorIdOrderByCreatedAtDesc(vendorId);
    }

    public record VendorEarnings(UUID vendorId, long completedSalesMinor, long platformCommissionMinor,
                                 long totalPayableMinor) {}
}
