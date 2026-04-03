package com.gasthaus.security;

import com.gasthaus.service.UserService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

/**
 * JWT authentication filter — runs once per HTTP request.
 *
 * NestJS equivalent: JwtAuthGuard (which delegates to JwtStrategy.validate()).
 * In NestJS, @UseGuards(JwtAuthGuard) on a route triggers passport-jwt to:
 *   1. Extract Bearer token from Authorization header
 *   2. Verify signature and expiry
 *   3. Call JwtStrategy.validate(payload) → looks up user from DB
 *   4. Attach user to req.user
 *
 * In Spring Security, the same flow is done by this filter:
 *   1. Read Authorization header → strip "Bearer "
 *   2. Validate token via JwtUtil
 *   3. Load User entity from DB via UserService
 *   4. Set UsernamePasswordAuthenticationToken in SecurityContextHolder
 *      (Spring's equivalent of req.user — retrieved via @AuthenticationPrincipal)
 *
 * OncePerRequestFilter guarantees this runs exactly once per request,
 * even when a request is forwarded internally.
 *
 * @RequiredArgsConstructor (Lombok) generates a constructor for all final fields,
 * which Spring uses for constructor injection (preferred over @Autowired).
 */
@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserService userService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        // ── Step 1: Extract token from "Authorization: Bearer <token>" header ──
        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            // No token present — pass request to next filter.
            // Spring Security will reject it if the route requires authentication.
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7); // strip "Bearer " prefix

        // ── Step 2: Validate token (signature + expiry) ──
        if (!jwtUtil.isTokenValid(token)) {
            // Bad token — continue without setting authentication.
            // SecurityContextHolder stays empty → 401 on protected routes.
            filterChain.doFilter(request, response);
            return;
        }

        // ── Step 3: Load user from DB ──
        // Like JwtStrategy.validate(payload) calling usersService.findById(payload.sub)
        UUID userId = jwtUtil.extractUserId(token);
        String role = jwtUtil.extractRole(token);

        // Only authenticate if not already done (avoids redundant DB hits on forwarded requests)
        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            userService.findById(userId).ifPresent(user -> {

                // ── Step 4: Build Spring Security authentication object ──
                // UsernamePasswordAuthenticationToken is Spring's standard
                // "authenticated user" object. Its three arguments are:
                //   principal   → the User entity (becomes @AuthenticationPrincipal in controllers)
                //   credentials → null (we don't keep the password around post-auth)
                //   authorities → the user's roles as GrantedAuthority objects
                //
                // Spring's hasRole('MANAGER') checks for "ROLE_MANAGER" in authorities,
                // so we prefix the role name: "ROLE_" + "MANAGER" = "ROLE_MANAGER".
                // NestJS equivalent: the role on req.user checked by RolesGuard.
                var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role));

                var authToken = new UsernamePasswordAuthenticationToken(
                        user,      // principal — available as @AuthenticationPrincipal User user
                        null,      // credentials
                        authorities
                );

                // Attach request metadata (IP, session ID) — used by Spring Security internals
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                // Set in SecurityContextHolder — this is the equivalent of "req.user = user"
                // All subsequent code in this request can read Authentication from here.
                SecurityContextHolder.getContext().setAuthentication(authToken);
            });
        }

        // ── Step 5: Continue the filter chain ──
        filterChain.doFilter(request, response);
    }
}
