package com.bhook.social.api;

import com.bhook.common.security.AuthContext;
import com.bhook.social.domain.Friendship;
import com.bhook.social.service.FriendshipService;
import com.bhook.social.api.dto.FriendshipView;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1/social/friends")
@RequiredArgsConstructor
public class FriendshipController {

    private final FriendshipService friendshipService;

    @PostMapping("/request")
    public ResponseEntity<Friendship> request(@RequestBody FriendRequest req, HttpServletRequest http) {
        return ResponseEntity.status(201).body(
                friendshipService.request(AuthContext.requireUserId(), bearer(http), req.friendCode()));
    }

    @PostMapping("/{friendshipId}/accept")
    public Friendship accept(@PathVariable UUID friendshipId) {
        return friendshipService.respond(AuthContext.requireUserId(), friendshipId, true);
    }

    @PostMapping("/{friendshipId}/decline")
    public Friendship decline(@PathVariable UUID friendshipId) {
        return friendshipService.respond(AuthContext.requireUserId(), friendshipId, false);
    }

    @DeleteMapping("/{friendshipId}")
    public ResponseEntity<Void> remove(@PathVariable UUID friendshipId) {
        friendshipService.remove(AuthContext.requireUserId(), friendshipId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/block")
    public Friendship block(@RequestBody BlockRequest req) {
        return friendshipService.block(AuthContext.requireUserId(), req.userId());
    }

    @GetMapping
    public List<Friendship> list() {
        return friendshipService.listAccepted(AuthContext.requireUserId());
    }

    @GetMapping("/pending")
    public List<Friendship> pending() {
        return friendshipService.listIncomingPending(AuthContext.requireUserId());
    }

    @GetMapping("/relationships")
    public List<FriendshipView> relationships(HttpServletRequest http) {
        return friendshipService.relationships(AuthContext.requireUserId(), bearer(http));
    }

    private String bearer(HttpServletRequest request) {
        String value = request.getHeader("Authorization");
        return value != null && value.startsWith("Bearer ") ? value.substring(7) : "";
    }

    public record FriendRequest(@NotNull String friendCode) {}
    public record BlockRequest(@NotNull UUID userId) {}
}
