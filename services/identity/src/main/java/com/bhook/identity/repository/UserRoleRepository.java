package com.bhook.identity.repository;

import com.bhook.identity.domain.RoleName;
import com.bhook.identity.domain.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface UserRoleRepository extends JpaRepository<UserRole, UUID> {
    List<UserRole> findByUserId(UUID userId);
    boolean existsByRoleName(RoleName roleName);
}
