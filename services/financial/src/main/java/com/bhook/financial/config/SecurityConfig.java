package com.bhook.financial.config;

import com.bhook.common.error.GlobalExceptionHandler;
import com.bhook.common.security.ResourceServerSecurity;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

@Configuration
@EnableMethodSecurity(prePostEnabled = true)
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
