package com.gasthaus.security;

import com.gasthaus.entity.enums.Role;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

/**
 * Utility for generating and validating JWT tokens.
 *
 * NestJS equivalent: @nestjs/jwt's JwtService.
 * In NestJS, JwtService.sign({ sub, email, role }) generates the token.
 * In NestJS, JwtStrategy validates the token and calls validate(payload).
 *
 * Here we combine both responsibilities in one class:
 *   - generateToken()      → JwtService.sign()
 *   - extractAllClaims()   → parsing / validation
 *   - isTokenValid()       → JwtStrategy's implicit validation
 *
 * Library: JJWT 0.12.x (see pom.xml). The API changed significantly from
 * 0.11.x — builder methods are now fluent without "set" prefix:
 *   OLD: .setSubject(id).setExpiration(date).signWith(key, algo)
 *   NEW: .subject(id).expiration(date).signWith(key)   ← algorithm inferred from key type
 *
 * Token structure (same as NestJS):
 *   { sub: userId, email: "...", role: "MANAGER", iat: ..., exp: ... }
 */
@Component
public class JwtUtil {

    /**
     * The signing key derived from the secret string in application.properties.
     * We defer initialization to @PostConstruct so @Value injection happens first.
     */
    private SecretKey secretKey;

    /**
     * Token lifetime in milliseconds (86400000 = 24 hours).
     * Mirrors NestJS JWT_EXPIRATION / signOptions.expiresIn.
     */
    @Value("${app.jwt.expiration}")
    private long expirationMs;

    /**
     * Raw secret string injected from application.properties.
     * @PostConstruct converts it to a SecretKey after injection.
     */
    @Value("${app.jwt.secret}")
    private String secret;

    /**
     * @PostConstruct runs after Spring injects all @Value fields.
     * We convert the raw secret string into a HMAC-SHA key object.
     * Keys.hmacShaKeyFor() selects SHA-256/384/512 based on key length:
     *   ≥ 256 bits → HS256, ≥ 384 bits → HS384, ≥ 512 bits → HS512
     *
     * Note: @PostConstruct requires a no-arg method — @Value must be on
     * a field, not a parameter, for this pattern to work.
     */
    @PostConstruct
    public void init() {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Generates a signed JWT token.
     *
     * NestJS equivalent: this.jwtService.sign({ sub: userId, email, role })
     *
     * Claims added:
     *   subject → userId (standard JWT "sub" claim, accessed via getSubject())
     *   email   → custom claim
     *   role    → custom claim (stored as string e.g. "MANAGER")
     */
    public String generateToken(UUID userId, String email, Role role) {
        return Jwts.builder()
                .subject(userId.toString())          // standard "sub" claim
                .claim("email", email)
                .claim("role", role.name())          // enum → "MANAGER", "WAITER", etc.
                .issuedAt(new Date())                // iat
                .expiration(new Date(System.currentTimeMillis() + expirationMs)) // exp
                .signWith(secretKey)                 // signs with HS256/384/512
                .compact();                          // serializes to the "aaa.bbb.ccc" string
    }

    /**
     * Parses the token and returns all claims.
     * Throws JwtException if the token is expired, tampered, or malformed.
     *
     * NestJS equivalent: passport-jwt extracts and verifies claims automatically
     * before calling JwtStrategy.validate(payload).
     */
    public Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)    // sets the key for signature verification
                .build()
                .parseSignedClaims(token) // parses + verifies in one call
                .getPayload();            // returns the Claims map
    }

    /**
     * Returns true if the token can be parsed and is not expired.
     * Used in JwtAuthFilter before touching the claims.
     */
    public boolean isTokenValid(String token) {
        try {
            extractAllClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    /** Extracts the user ID (stored in the "sub" claim) as a UUID. */
    public UUID extractUserId(String token) {
        return UUID.fromString(extractAllClaims(token).getSubject());
    }

    /** Extracts the role string (e.g. "MANAGER") from the custom "role" claim. */
    public String extractRole(String token) {
        return extractAllClaims(token).get("role", String.class);
    }
}
