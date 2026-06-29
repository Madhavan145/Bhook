package com.bhook.upload.service;

import com.bhook.common.error.BhookException;
import com.bhook.upload.domain.UploadPurpose;
import com.bhook.upload.domain.UploadedObject;
import com.bhook.upload.repository.UploadedObjectRepository;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.MinioClient;
import io.minio.StatObjectArgs;
import io.minio.http.Method;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.io.ByteArrayInputStream;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class UploadService {

    private static final Map<UploadPurpose, Set<String>> ALLOWED_TYPES = Map.of(
            UploadPurpose.CATALOG_IMAGE,         Set.of("image/jpeg", "image/png", "image/webp"),
            UploadPurpose.VENDOR_LOGO,           Set.of("image/jpeg", "image/png", "image/webp"),
            UploadPurpose.VENDOR_COVER,          Set.of("image/jpeg", "image/png", "image/webp"),
            UploadPurpose.PROFILE_IMAGE,         Set.of("image/jpeg", "image/png", "image/webp"),
            UploadPurpose.DELIVERY_PROOF,        Set.of("image/jpeg", "image/png"),
            UploadPurpose.VERIFICATION_DOCUMENT, Set.of("image/jpeg", "image/png", "application/pdf"),
            UploadPurpose.SUPPORT_ATTACHMENT,    Set.of("image/jpeg", "image/png", "application/pdf")
    );

    private static final Set<UploadPurpose> RESTRICTED_READ =
            Set.of(UploadPurpose.VERIFICATION_DOCUMENT, UploadPurpose.SUPPORT_ATTACHMENT);

    private final MinioClient minioClient;
    @Qualifier("presignMinioClient")
    private final MinioClient presignMinioClient;
    private final UploadedObjectRepository repository;

    @Value("${bhook.storage.bucket}") private String bucket;
    @Value("${bhook.storage.public-endpoint:}") private String publicEndpoint;
    @Value("${bhook.storage.presign-expiry-seconds:900}") private int presignExpirySeconds;
    @Value("${bhook.storage.max-size-bytes:5242880}") private long maxSizeBytes;

    public record CreateResult(UUID uploadId, String objectKey, String uploadUrl,
                               long expiresInSeconds, long maxSizeBytes, String contentType) {}

    @Transactional
    public CreateResult createPresignedUpload(UUID userId, UploadPurpose purpose, String contentType, long sizeBytes) {
        if (sizeBytes < 0 || sizeBytes > maxSizeBytes) {
            throw BhookException.validation("File size out of range");
        }
        Set<String> allowed = ALLOWED_TYPES.getOrDefault(purpose, Set.of());
        if (!allowed.contains(contentType)) {
            throw BhookException.validation("Content type " + contentType + " not allowed for " + purpose);
        }
        String objectKey = purpose.name().toLowerCase() + "/" + userId + "/" + UUID.randomUUID() + extension(contentType);
        UploadedObject obj = UploadedObject.builder()
                .userId(userId).purpose(purpose)
                .objectKey(objectKey).bucket(bucket)
                .contentType(contentType).sizeBytes(sizeBytes)
                .uploadStatus("PENDING")
                .expiresAt(Instant.now().plus(presignExpirySeconds, ChronoUnit.SECONDS))
                .build();
        obj = repository.save(obj);

        String presignedUrl;
        try {
            presignedUrl = presignMinioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .method(Method.PUT).bucket(bucket).object(objectKey)
                    .expiry(presignExpirySeconds, TimeUnit.SECONDS)
                    .build());
        } catch (Exception e) {
            log.error("Failed to presign upload for {}: {}", objectKey, e.toString());
            throw BhookException.validation("Presign failed");
        }
        return new CreateResult(obj.getId(), objectKey, presignedUrl, presignExpirySeconds, maxSizeBytes, contentType);
    }

    @Transactional
    public UploadedObject commit(UUID userId, UUID uploadId, String sha256) {
        UploadedObject obj = repository.findById(uploadId)
                .orElseThrow(() -> BhookException.notFound("Upload not found"));
        if (!obj.getUserId().equals(userId)) {
            throw BhookException.forbidden("Upload does not belong to this user");
        }
        if ("COMMITTED".equals(obj.getUploadStatus())) return obj;
        try {
            var stat = minioClient.statObject(StatObjectArgs.builder()
                    .bucket(obj.getBucket()).object(obj.getObjectKey()).build());
            if (stat.size() != obj.getSizeBytes()) {
                throw BhookException.validation("Upload size mismatch");
            }
            if (!baseType(stat.contentType()).equals(baseType(obj.getContentType()))) {
                throw BhookException.validation("Content type mismatch");
            }
        } catch (BhookException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Object not found in storage yet: {}", obj.getObjectKey());
            throw BhookException.validation("Object not uploaded");
        }
        obj.setSha256(sha256);
        obj.setUploadStatus("COMMITTED");
        obj.setCommittedAt(Instant.now());
        return repository.save(obj);
    }

    public void uploadContent(UUID userId, UUID uploadId, byte[] content, String contentType) {
        UploadedObject obj = repository.findById(uploadId)
                .orElseThrow(() -> BhookException.notFound("Upload not found"));
        if (!obj.getUserId().equals(userId)) throw BhookException.forbidden("Upload does not belong to this user");
        if (content.length != obj.getSizeBytes()) throw BhookException.validation("Upload size mismatch");
        if (!baseType(obj.getContentType()).equals(baseType(contentType))) throw BhookException.validation("Content type mismatch");
        try {
            minioClient.putObject(io.minio.PutObjectArgs.builder()
                    .bucket(obj.getBucket())
                    .object(obj.getObjectKey())
                    .stream(new ByteArrayInputStream(content), content.length, -1)
                    .contentType(contentType)
                    .build());
        } catch (Exception e) {
            log.error("Failed to store upload {}: {}", uploadId, e.toString());
            throw BhookException.validation("Upload failed");
        }
    }

    public String presignedReadUrl(UUID userId, boolean platformAdmin, UUID uploadId) {
        UploadedObject obj = repository.findById(uploadId)
                .orElseThrow(() -> BhookException.notFound("Upload not found"));
        if (!"COMMITTED".equals(obj.getUploadStatus())) {
            throw BhookException.validation("Upload not committed");
        }
        if (RESTRICTED_READ.contains(obj.getPurpose()) && !platformAdmin && !obj.getUserId().equals(userId)) {
            throw BhookException.forbidden("Not authorized to read this object");
        }
        try {
                return browserUrl(presignMinioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .method(Method.GET).bucket(obj.getBucket()).object(obj.getObjectKey())
                    .expiry(presignExpirySeconds, TimeUnit.SECONDS)
                    .build()));
        } catch (Exception e) {
            log.error("Failed to presign read for {}: {}", obj.getObjectKey(), e.toString());
            throw BhookException.validation("Presign failed");
        }
    }

    private static String baseType(String contentType) {
        if (contentType == null) return "";
        int semi = contentType.indexOf(';');
        return (semi >= 0 ? contentType.substring(0, semi) : contentType).trim().toLowerCase();
    }

    private String extension(String contentType) {
        return switch (contentType) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "application/pdf" -> ".pdf";
            default -> "";
        };
    }

    private String browserUrl(String internalUrl) {
        if (publicEndpoint == null || publicEndpoint.isBlank()) return internalUrl;
        try {
            var internal = java.net.URI.create(internalUrl);
            var external = java.net.URI.create(publicEndpoint);
            return new java.net.URI(
                    external.getScheme(),
                    external.getUserInfo(),
                    external.getHost(),
                    external.getPort(),
                    internal.getPath(),
                    internal.getQuery(),
                    internal.getFragment()).toString();
        } catch (Exception e) {
            log.warn("Could not rewrite storage URL for browser access: {}", e.toString());
            return internalUrl;
        }
    }
}
