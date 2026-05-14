package com.bhook.common.security;

import com.bhook.common.web.CorrelationIdFilter;
import com.bhook.common.web.CorsConfig;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

@Configuration
@EnableConfigurationProperties(JwtProperties.class)
@ComponentScan(basePackageClasses = {JwtService.class, CorrelationIdFilter.class})
@Import(CorsConfig.class)
public class ResourceServerSecurity {

    @Autowired(required = false)
    private SecurityPolicy policy;

    @Bean
    public SecurityFilterChain resourceServerFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter,
                                                         @Qualifier("corsConfigurationSource") CorsConfigurationSource corsSource,
                                                         BhookAuthenticationEntryPoint authenticationEntryPoint,
                                                         BhookAccessDeniedHandler accessDeniedHandler) throws Exception {
        String[] publicPaths = policy != null ? policy.publicPaths() : new String[]{
                "/actuator/health", "/actuator/info", "/v3/api-docs/**", "/swagger-ui/**"
        };
        http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsSource))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(publicPaths).permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    public interface SecurityPolicy {
        String[] publicPaths();
    }
}
