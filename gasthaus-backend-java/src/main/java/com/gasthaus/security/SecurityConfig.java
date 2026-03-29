package com.gasthaus.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * Spring Security configuration.
 *
 * NestJS equivalent: the combination of:
 *   - app.enableCors() in main.ts
 *   - JwtAuthGuard applied globally or per-route via @UseGuards
 *   - RolesGuard applied via @UseGuards + @Roles decorator
 *   - ValidationPipe (handled by @Valid + Bean Validation, not here)
 *
 * Spring Boot 3.x uses the new component-based style (no more extending
 * WebSecurityConfigurerAdapter — that was removed in Spring Boot 3.0).
 * Instead, we declare @Bean methods that return SecurityFilterChain.
 *
 * @EnableWebSecurity       — activates Spring Security's web support
 * @EnableMethodSecurity    — enables @PreAuthorize on controller methods
 *                            (NestJS equivalent: @Roles() + RolesGuard)
 *                            hasRole('MANAGER') checks for "ROLE_MANAGER" in authorities.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    /**
     * Defines the HTTP security rules and filter chain.
     *
     * Think of this as the combined configuration of:
     *   - NestJS's app.enableCors()
     *   - NestJS's @UseGuards(JwtAuthGuard) applied globally
     *   - Which routes are public vs. protected
     *
     * The filter chain is a pipeline of filters each request passes through.
     * Our JwtAuthFilter is inserted just before Spring's built-in
     * UsernamePasswordAuthenticationFilter.
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                   JwtAuthFilter jwtAuthFilter) throws Exception {
        http
            // ── CSRF: Disable for REST APIs ──
            // CSRF attacks exploit browser cookie behavior.
            // Since we use Authorization: Bearer (not cookies), CSRF is not a threat.
            // NestJS doesn't enable CSRF protection either.
            .csrf(AbstractHttpConfigurer::disable)

            // ── CORS: Allow cross-origin requests ──
            // NestJS equivalent: app.enableCors()
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))

            // ── Session: Stateless ──
            // We use JWT — no server-side sessions. Every request is self-contained.
            // NestJS with passport-jwt is also stateless by default.
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // ── Authorization rules ──
            // Maps 1:1 to which NestJS routes have @UseGuards(JwtAuthGuard) or are public.
            // Routes are matched WITHOUT the /api prefix (context-path is stripped by servlet).
            .authorizeHttpRequests(auth -> auth

                // ── Spring Boot error endpoint ──
                // When any exception is thrown, Spring forwards to /error (Tomcat error dispatch).
                // That dispatch runs through the security filter chain as a new request.
                // Without permitAll() here, anonymous error dispatches get 403 instead of the
                // original status code. This is the REST API equivalent of configuring errorPage.
                .requestMatchers("/error").permitAll()

                // ── WebSocket / SockJS handshake ──
                // SockJS probes the server with GET /ws/info before upgrading to WebSocket.
                // This plain HTTP request carries no Authorization header, so it must be
                // permitted here. The STOMP connection itself is trusted (staff-only app).
                .requestMatchers("/ws/**").permitAll()

                // ── Public auth routes ──
                .requestMatchers(HttpMethod.POST, "/auth/login", "/auth/register").permitAll()

                // ── Public menu browsing (GET only) ──
                // NestJS: GET /menu/categories and GET /menu/items have no guard
                .requestMatchers(HttpMethod.GET, "/menu/categories", "/menu/items", "/menu/items/**").permitAll()

                // ── Public table QR scan ──
                // NestJS: GET /tables/number/:num has no guard
                .requestMatchers(HttpMethod.GET, "/tables/number/**").permitAll()

                // ── Public review reading and AI review summary ──
                .requestMatchers(HttpMethod.GET, "/reviews/item/**").permitAll()
                .requestMatchers(HttpMethod.POST, "/ai/review-summary").permitAll()

                // ── Everything else requires a valid JWT ──
                // Fine-grained role checks are done via @PreAuthorize on controller methods.
                .anyRequest().authenticated()
            )

            // ── Insert our JWT filter before Spring's default auth filter ──
            // Without this, requests would hit the route handler before JWT is validated.
            // NestJS equivalent: registering JwtAuthGuard as a global guard.
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * BCrypt password encoder.
     *
     * NestJS equivalent: bcrypt.hash(password, 10) / bcrypt.compare(password, hash)
     * Spring's BCryptPasswordEncoder uses cost factor 10 by default — same as NestJS.
     *
     * Declared as a @Bean so it can be injected wherever needed (AuthService, tests).
     * Spring Security also picks it up automatically for its internal auth mechanisms.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }

    /**
     * CORS configuration.
     *
     * NestJS equivalent: app.enableCors() with default settings.
     * We mirror NestJS's permissive defaults here (allow all origins in dev).
     * Tighten origin list for production.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();

        // allowedOriginPatterns supports wildcards + credentials (allowedOrigins("*") + credentials is illegal)
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
