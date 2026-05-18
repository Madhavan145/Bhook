package com.bhook.identity.repository;

import com.bhook.identity.domain.OtpChallenge;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface OtpChallengeRepository extends JpaRepository<OtpChallenge, UUID> {
}
