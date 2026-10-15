package com.bhook.upload.repository;

import com.bhook.upload.domain.UploadedObject;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface UploadedObjectRepository extends JpaRepository<UploadedObject, UUID> {
    List<UploadedObject> findByUploadStatusAndExpiresAtBefore(String uploadStatus, Instant cutoff);
}
