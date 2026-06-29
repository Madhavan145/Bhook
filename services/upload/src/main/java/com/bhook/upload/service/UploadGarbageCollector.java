package com.bhook.upload.service;

import com.bhook.upload.domain.UploadedObject;
import com.bhook.upload.repository.UploadedObjectRepository;
import io.minio.MinioClient;
import io.minio.RemoveObjectArgs;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class UploadGarbageCollector {

    private final UploadedObjectRepository repository;
    private final MinioClient minioClient;

    @Scheduled(cron = "${bhook.storage.gc-cron:0 */15 * * * *}")
    @Transactional
    public void purgeExpiredPending() {
        Instant cutoff = Instant.now();
        List<UploadedObject> stale = repository.findByUploadStatusAndExpiresAtBefore("PENDING", cutoff);
        if (stale.isEmpty()) return;
        for (UploadedObject obj : stale) {
            try {
                minioClient.removeObject(RemoveObjectArgs.builder()
                        .bucket(obj.getBucket()).object(obj.getObjectKey()).build());
            } catch (Exception e) {
                log.debug("Object {} was not in storage or removal failed: {}", obj.getObjectKey(), e.toString());
            }
            repository.delete(obj);
        }
        log.info("Upload GC purged {} expired pending uploads", stale.size());
    }
}
