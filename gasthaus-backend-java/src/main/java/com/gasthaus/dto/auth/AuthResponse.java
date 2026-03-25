package com.gasthaus.dto.auth;

/**
 * Response body for POST /auth/register and POST /auth/login.
 *
 * NestJS equivalent: { user, token } returned by AuthService.register() and .login()
 *
 * Jackson serializes this record to:
 *   { "user": { "id": "...", "name": "...", ... }, "token": "eyJ..." }
 */
public record AuthResponse(UserResponse user, String token) {
}
