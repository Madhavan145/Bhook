package com.bhook.customer.repository;

import com.bhook.customer.domain.MembershipVerification;
import com.bhook.customer.domain.VerificationStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MembershipVerificationRepository extends JpaRepository<MembershipVerification, UUID> {
    List<MembershipVerification> findByMembershipIdOrderByCreatedAtDesc(UUID membershipId);
    List<MembershipVerification> findByUserIdOrderByCreatedAtDesc(UUID userId);
    List<MembershipVerification> findByStatusOrderByCreatedAtAsc(VerificationStatus status);
}
