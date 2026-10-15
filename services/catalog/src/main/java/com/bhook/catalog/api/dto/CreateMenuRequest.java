package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateMenuRequest(@NotBlank @Size(max = 120) String name) {}
