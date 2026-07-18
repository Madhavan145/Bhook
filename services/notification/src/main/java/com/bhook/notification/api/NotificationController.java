package com.bhook.notification.api;

import com.bhook.common.security.AuthContext;
import com.bhook.notification.domain.Notification;
import com.bhook.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationRepository repository;

    @GetMapping
    public List<Notification> list() {
        return repository.findByUserIdOrderByCreatedAtDesc(AuthContext.requireUserId());
    }

    @PatchMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@PathVariable UUID id) {
        repository.findById(id).ifPresent(n -> {
            n.setReadAt(Instant.now());
            repository.save(n);
        });
        return ResponseEntity.noContent().build();
    }
}
