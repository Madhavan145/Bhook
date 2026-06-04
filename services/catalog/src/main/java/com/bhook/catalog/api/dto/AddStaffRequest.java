package com.bhook.catalog.api.dto;

import com.bhook.catalog.domain.VendorRole;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record AddStaffRequest(@NotNull UUID userId, @NotNull VendorRole role) {}
