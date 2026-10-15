package com.bhook.upload.api;

import com.bhook.common.security.AuthContext;
import com.bhook.upload.domain.UploadPurpose;
import com.bhook.upload.domain.UploadedObject;
import com.bhook.upload.service.UploadService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/uploads")
@RequiredArgsConstructor
public class UploadController {

    private final UploadService uploadService;

    @PostMapping
    public ResponseEntity<UploadService.CreateResult> create(@Valid @RequestBody CreateRequest req) {
        UploadService.CreateResult result = uploadService.createPresignedUpload(
                AuthContext.requireUserId(), req.purpose(), req.contentType(), req.sizeBytes());
        return ResponseEntity.status(201).body(result);
    }

    @PostMapping("/{uploadId}/commit")
    public UploadedObject commit(@PathVariable UUID uploadId, @Valid @RequestBody CommitRequest req) {
        return uploadService.commit(AuthContext.requireUserId(), uploadId, req.sha256());
    }

    @PutMapping("/{uploadId}/content")
    public ResponseEntity<Void> uploadContent(@PathVariable UUID uploadId,
                                               @RequestBody byte[] content,
                                               @RequestHeader(value = "Content-Type", defaultValue = "application/octet-stream") String contentType) {
        uploadService.uploadContent(AuthContext.requireUserId(), uploadId, content, contentType);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{uploadId}/download-url")
    public DownloadUrl downloadUrl(@PathVariable UUID uploadId) {
        boolean isPlatformAdmin = isPlatformAdmin();
        return new DownloadUrl(uploadService.presignedReadUrl(AuthContext.requireUserId(), isPlatformAdmin, uploadId));
    }

    private boolean isPlatformAdmin() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return false;
        return auth.getAuthorities().stream().anyMatch(a ->
                a.getAuthority().equals("ROLE_PLATFORM_SUPER_ADMIN")
                        || a.getAuthority().equals("ROLE_PLATFORM_ADMIN")
                        || a.getAuthority().equals("ROLE_PLATFORM_OPERATIONS")
                        || a.getAuthority().equals("ROLE_PLATFORM_SUPPORT"));
    }

    public record CreateRequest(
            @NotNull UploadPurpose purpose,
            @NotBlank @Size(max = 128) String contentType,
            @PositiveOrZero long sizeBytes
    ) {}

    public record CommitRequest(@Size(max = 128) String sha256) {}

    public record DownloadUrl(String url) {}
}
