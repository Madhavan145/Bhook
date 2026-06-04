package com.bhook.catalog.api.dto;

import jakarta.validation.constraints.Size;

public record UpdateMenuRequest(@Size(max = 120) String name) {}