package com.bhook.identity.api;

import com.bhook.identity.api.dto.ProvisionUserRequest;
import com.bhook.identity.api.dto.ProvisionUserResponse;
import com.bhook.identity.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/platform/users")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PLATFORM_SUPER_ADMIN','PLATFORM_ADMIN')")
public class PlatformUserController {

    private final AuthService authService;

    @PostMapping
    public ResponseEntity<ProvisionUserResponse> provision(@Valid @RequestBody ProvisionUserRequest req) {
        return ResponseEntity.status(201).body(authService.provisionUser(req));
    }
}
