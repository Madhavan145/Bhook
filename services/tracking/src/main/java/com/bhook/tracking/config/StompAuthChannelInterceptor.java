package com.bhook.tracking.config;

import com.bhook.common.security.AuthenticatedPrincipal;
import com.bhook.common.security.JwtService;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class StompAuthChannelInterceptor implements ChannelInterceptor {

    private final JwtService jwtService;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || !StompCommand.CONNECT.equals(accessor.getCommand())) {
            return message;
        }
        String header = accessor.getFirstNativeHeader("Authorization");
        String token = null;
        if (header != null && header.startsWith("Bearer ")) {
            token = header.substring(7);
        } else {
            String qp = (String) accessor.getSessionAttributes().get("access_token");
            if (qp != null && !qp.isBlank()) token = qp;
        }
        if (token == null) {
            log.debug("STOMP CONNECT without Authorization header");
            return message;
        }
        try {
            Claims claims = jwtService.parse(token);
            @SuppressWarnings("unchecked")
            List<String> roles = claims.get("roles", List.class);
            String sessionId = claims.get("sessionId", String.class);
            UUID userId = UUID.fromString(claims.getSubject());
            AuthenticatedPrincipal principal = new AuthenticatedPrincipal(
                    userId, sessionId,
                    roles == null ? List.of() : roles,
                    List.of()
            );
            var authorities = principal.roles().stream()
                    .map(r -> new SimpleGrantedAuthority("ROLE_" + r))
                    .toList();
            var auth = new UsernamePasswordAuthenticationToken(principal, null, authorities);
            accessor.setUser(auth);
        } catch (Exception e) {
            log.debug("STOMP CONNECT rejected: {}", e.toString());
        }
        return message;
    }
}
