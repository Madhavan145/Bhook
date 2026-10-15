package com.bhook.order.config;

import com.bhook.common.error.GlobalExceptionHandler;
import com.bhook.common.security.ResourceServerSecurity;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

@Configuration
@Import({GlobalExceptionHandler.class, ResourceServerSecurity.class})
public class SecurityConfig implements ResourceServerSecurity.SecurityPolicy {

    @Override
    public String[] publicPaths() {
        return new String[]{
                "/actuator/health",
                "/actuator/info",
                "/v3/api-docs/**",
                "/swagger-ui/**"
        };
    }
}
