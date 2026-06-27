package com.bhook.payment.api;

import com.bhook.payment.domain.PaymentAttempt;
import com.bhook.payment.domain.Refund;
import com.bhook.payment.repository.PaymentAttemptRepository;
import com.bhook.payment.service.PaymentService;
import com.bhook.payment.service.RefundService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;
    private final RefundService refundService;
    private final PaymentAttemptRepository attemptRepository;

    @PostMapping(value = "/webhook", consumes = "application/json")
    public ResponseEntity<Void> webhook(@RequestBody String body,
                                        @RequestHeader(value = "X-Bhook-Signature", required = false) String signature) {
        paymentService.handleCallback(body, signature);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{attemptId}/simulate-success")
    public PaymentAttempt simulate(@PathVariable UUID attemptId) {
        return paymentService.simulateSuccess(attemptId);
    }

    @GetMapping("/orders/{orderId}/attempts")
    public List<PaymentAttempt> attemptsForOrder(@PathVariable UUID orderId) {
        return attemptRepository.findByOrderIdOrderByCreatedAtDesc(orderId);
    }

    @PostMapping("/orders/{orderId}/refund")
    @PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN','PLATFORM_OPERATIONS','PLATFORM_FINANCE','PLATFORM_SUPPORT')")
    public Refund refund(@PathVariable UUID orderId, @RequestBody RefundRequest req) {
        return refundService.refundOrder(orderId, req.reason());
    }

    public record RefundRequest(String reason) {}
}
