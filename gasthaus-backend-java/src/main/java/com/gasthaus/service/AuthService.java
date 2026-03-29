package com.gasthaus.service;

import com.gasthaus.dto.auth.AuthResponse;
import com.gasthaus.dto.auth.LoginRequest;
import com.gasthaus.dto.auth.RegisterRequest;
import com.gasthaus.dto.auth.RegisterStaffRequest;
import com.gasthaus.dto.auth.UserResponse;
import com.gasthaus.entity.User;
import com.gasthaus.entity.enums.Role;
import com.gasthaus.security.JwtUtil;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Handles registration, login, and token generation.
 *
 * NestJS equivalent: AuthService in src/auth/auth.service.ts
 *
 * Responsibilities:
 *   - register() → validate → create user via UserService → issue JWT
 *   - login()    → find user → compare password → issue JWT
 *   - signToken() → delegate to JwtUtil.generateToken()
 *
 * This service depends on UserService (for DB access) and JwtUtil (for token
 * generation). We deliberately keep JwtUtil out of controllers to mirror
 * NestJS's separation: AuthService uses JwtService, controllers don't.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserService userService;
    private final JwtUtil jwtUtil;
    private final PasswordEncoder passwordEncoder;

    // ─── register ───────────────────────────────────────────────

    /**
     * NestJS:
     *   async register(name, email, password, role?) {
     *     const user = await this.usersService.create(name, email, password, role);
     *     const token = this.signToken(user.id, user.email, user.role);
     *     return { user, token };
     *   }
     *
     * UserService.create() handles the duplicate email check and bcrypt hashing.
     * We then sign a JWT and return both together as AuthResponse.
     */
    /** Public registration — always creates CUSTOMER. Role field not accepted. */
    public AuthResponse register(RegisterRequest dto) {
        User user = userService.create(dto.getName(), dto.getEmail(), dto.getPassword(), Role.CUSTOMER);
        String token = signToken(user);
        return new AuthResponse(UserResponse.from(user), token);
    }

    /** Staff registration — MANAGER only. Creates KITCHEN or MANAGER accounts. */
    public AuthResponse registerStaff(RegisterStaffRequest dto) {
        if (dto.getRole() == Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Use /auth/register to create customer accounts.");
        }
        User user = userService.create(dto.getName(), dto.getEmail(), dto.getPassword(), dto.getRole());
        String token = signToken(user);
        return new AuthResponse(UserResponse.from(user), token);
    }

    // ─── login ──────────────────────────────────────────────────

    /**
     * NestJS:
     *   async login(email, password) {
     *     const user = await this.usersService.findByEmail(email);
     *     if (!user) { ... throw UnauthorizedException }
     *     const valid = await bcrypt.compare(password, user.password);
     *     if (!valid) throw new UnauthorizedException('Invalid credentials');
     *     const { password: _, ...safeUser } = user;
     *     const token = this.signToken(user.id, user.email, user.role);
     *     return { user: safeUser, token };
     *   }
     *
     * Security note on timing attacks:
     * NestJS adds a random delay (80–120ms) when the user is not found, to prevent
     * an attacker from using response time to determine if an email is registered.
     *
     * Spring's PasswordEncoder.matches() always runs the full BCrypt comparison
     * (it doesn't short-circuit on "user not found"), so we run matches() regardless.
     * This gives us constant-time behavior without an explicit delay.
     *
     * We use a dummy hash as the target when no user is found, so BCrypt still
     * runs its full work factor — same defense as adding a delay.
     *
     * The dummyHash is pre-computed at startup via @PostConstruct so it is always
     * a valid BCrypt string — Spring's PasswordEncoder won't warn or short-circuit.
     */
    private String dummyHash;

    @PostConstruct
    public void initDummyHash() {
        this.dummyHash = passwordEncoder.encode("dummy-password-for-timing-safety");
    }

    public AuthResponse login(LoginRequest dto) {
        User user = userService.findByEmail(dto.getEmail()).orElse(null);

        // Always run BCrypt regardless of whether the user exists.
        // If user is null, compare against dummyHash — will fail, but BCrypt still runs fully.
        String storedHash = (user != null) ? user.getPassword() : dummyHash;
        boolean valid = passwordEncoder.matches(dto.getPassword(), storedHash);

        if (user == null || !valid) {
            // Same message for both cases — don't reveal whether the email exists.
            // NestJS: throw new UnauthorizedException('Invalid credentials')
            // Spring: ResponseStatusException with 401
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }

        String token = signToken(user);
        return new AuthResponse(UserResponse.from(user), token);
    }

    // ─── signToken (private) ─────────────────────────────────────

    /**
     * NestJS: private signToken(userId, email, role) { return this.jwtService.sign({ sub, email, role }) }
     *
     * Delegates to JwtUtil — this keeps the controller and service layer
     * unaware of the JWT implementation details.
     */
    private String signToken(User user) {
        return jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole());
    }
}
