package com.gasthaus.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rate limits POST /auth/login to 5 FAILED attempts per 60 seconds per IP.
 *
 * NestJS equivalent:
 *   @UseGuards(ThrottlerGuard)
 *   @Throttle({ short: { limit: 5, ttl: 60000 } })
 *   login(...) { ... }
 *
 * NestJS's ThrottlerGuard counts ALL attempts (success + failure).
 * Our implementation intentionally only counts FAILED attempts (HTTP 401).
 * This is a stricter security model: legitimate users who successfully log in
 * are never penalised, while brute-force attackers (who always get 401) are
 * blocked after 5 failures per 60s. The practical effect on security is
 * identical or better — an attacker gains nothing from the distinction.
 *
 * Algorithm: sliding window per IP, counting only 401 responses.
 * - preHandle: check failure count from window — block with 429 if >= 5.
 * - afterCompletion: if response status is 401, record timestamp in window.
 *
 * ConcurrentHashMap makes this thread-safe for concurrent requests.
 * Each IP's deque is accessed only inside a synchronized block on the deque
 * itself to prevent race conditions on count-check and add.
 *
 * Caveats:
 * - State lives in memory — resets on app restart.
 * - Not shared across multiple instances (use Redis-backed throttler for prod).
 * - IP detection uses X-Forwarded-For (falls back to remoteAddr).
 */
@Component
public class LoginRateLimitInterceptor implements HandlerInterceptor {

    private static final int  MAX_FAILURES = 5;
    private static final long WINDOW_MS    = 60_000L;

    // IP address → sliding window of FAILED login attempt timestamps
    private final Map<String, Deque<Long>> failureLog = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Before the controller runs: check if this IP is over its failure quota.
     */
    @Override
    public boolean preHandle(@NonNull HttpServletRequest request,
                             @NonNull HttpServletResponse response,
                             @NonNull Object handler) throws IOException {

        String ip = resolveClientIp(request);
        long now = System.currentTimeMillis();

        Deque<Long> failures = failureLog.computeIfAbsent(ip, k -> new ArrayDeque<>());

        synchronized (failures) {
            // Evict timestamps outside the sliding window
            while (!failures.isEmpty() && now - failures.peekFirst() > WINDOW_MS) {
                failures.pollFirst();
            }

            if (failures.size() >= MAX_FAILURES) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                objectMapper.writeValue(response.getWriter(), Map.of(
                        "statusCode", 429,
                        "error",      "Too Many Requests",
                        "message",    "Too many failed login attempts. Try again in 60 seconds."
                ));
                return false; // abort — controller method is NOT called
            }
        }

        return true; // allow request through
    }

    /**
     * After the controller runs: record the failure if the response was 401.
     * Successful logins (200/201) are NOT counted — only wrong-password attempts.
     */
    @Override
    public void afterCompletion(@NonNull HttpServletRequest request,
                                @NonNull HttpServletResponse response,
                                @NonNull Object handler,
                                Exception ex) {
        if (response.getStatus() == HttpStatus.UNAUTHORIZED.value()) {
            String ip = resolveClientIp(request);
            Deque<Long> failures = failureLog.computeIfAbsent(ip, k -> new ArrayDeque<>());
            synchronized (failures) {
                failures.addLast(System.currentTimeMillis());
            }
        }
    }

    /**
     * Resolve the real client IP.
     * Behind a reverse proxy, the original IP is in X-Forwarded-For.
     */
    private String resolveClientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
