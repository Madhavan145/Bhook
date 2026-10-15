package com.bhook.customer.service;

import com.bhook.common.error.BhookException;
import com.bhook.customer.domain.CustomerProfile;
import com.bhook.customer.api.dto.CustomerDirectoryEntry;
import com.bhook.customer.api.dto.UpdateCustomerProfileRequest;
import com.bhook.customer.repository.CustomerProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CustomerProfileService {

    private final CustomerProfileRepository repository;

    @Transactional
    public CustomerProfile ensureProfile(UUID userId, String displayName, String email, String phoneE164) {
        return repository.findByUserId(userId).map(existing -> {
            boolean changed = false;
            if (existing.getEmail() == null && email != null) { existing.setEmail(email.toLowerCase()); changed = true; }
            if (existing.getPhoneE164() == null && phoneE164 != null) { existing.setPhoneE164(phoneE164); changed = true; }
            return changed ? repository.save(existing) : existing;
        }).orElseGet(() ->
                repository.save(CustomerProfile.builder()
                        .userId(userId)
                        .friendCode(userId.toString())
                        .displayName(displayName)
                        .email(email != null ? email.toLowerCase() : null)
                        .phoneE164(phoneE164)
                        .verificationState("PENDING")
                        .build())
        );
    }

    @Transactional(readOnly = true)
    public CustomerProfile findByUserId(UUID userId) {
        return repository.findByUserId(userId)
                .orElseThrow(() -> BhookException.notFound("Customer profile not found"));
    }

    @Transactional
    public CustomerProfile setActiveCampus(UUID userId, UUID campusId) {
        CustomerProfile profile = findByUserId(userId);
        profile.setActiveCampusId(campusId);
        return repository.save(profile);
    }

    @Transactional
    public CustomerProfile updateProfile(UUID userId, UpdateCustomerProfileRequest req) {
        CustomerProfile profile = findByUserId(userId);
        if (req.displayName() != null && !req.displayName().isBlank()) {
            profile.setDisplayName(req.displayName().trim());
        }
        if (req.bio() != null) profile.setBio(req.bio().trim());
        if (req.profileImageObjectKey() != null) {
            String key = req.profileImageObjectKey().trim();
            String prefix = "profile_image/" + userId + "/";
            if (!key.startsWith(prefix)) {
                throw BhookException.validation("Profile image does not belong to this user");
            }
            profile.setProfileImageObjectKey(key);
        }
        return repository.save(profile);
    }

    @Transactional(readOnly = true)
    public CustomerDirectoryEntry findByFriendCode(UUID requesterId, String friendCode) {
        CustomerProfile profile = repository.findByFriendCode(friendCode.trim())
                .orElseThrow(() -> BhookException.notFound("Customer not found"));
        if (profile.getUserId().equals(requesterId)) {
            throw BhookException.validation("You cannot add yourself");
        }
        return new CustomerDirectoryEntry(
                profile.getUserId(), profile.getDisplayName(), profile.getProfileImageObjectKey(), profile.getFriendCode(), profile.getActiveCampusId());
    }
}
