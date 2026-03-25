package com.gasthaus.controller;

import com.gasthaus.dto.auth.AuthResponse;
import com.gasthaus.dto.auth.LoginRequest;
import com.gasthaus.dto.auth.RegisterRequest;
import com.gasthaus.dto.auth.UserResponse;
import com.gasthaus.entity.User;
import com.gasthaus.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Handles authentication endpoints: register, login, and me.
 *
 * NestJS equivalent: AuthController in src/auth/auth.controller.ts
 *
 * @RestController — combines @Controller + @ResponseBody.
 *   Every method returns data serialized to JSON, not a view template.
 *   NestJS equivalent: @Controller('auth') with methods that return plain objects.
 *
 * @RequestMapping("/auth") — sets the base path for all methods.
 *   Combined with server.servlet.context-path=/api, routes become:
 *     POST /api/auth/register
 *     POST /api/auth/login
 *     GET  /api/auth/me
 *   NestJS equivalent: @Controller('auth') on the class.
 *
 * @RequiredArgsConstructor — Lombok constructor injection for AuthService.
 */
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    // ─── POST /api/auth/register ─────────────────────────────────

    /**
     * NestJS:
     *   @Post('register')
     *   register(@Body() dto: RegisterDto) {
     *     return this.authService.register(dto.name, dto.email, dto.password, dto.role);
     *   }
     *
     * @Valid — triggers Bean Validation on RegisterRequest.
     *   If @NotBlank or @Email fails, Spring throws MethodArgumentNotValidException → 400.
     *   NestJS equivalent: ValidationPipe processes class-validator decorators.
     *
     * @RequestBody — deserializes the JSON body into RegisterRequest.
     *   NestJS equivalent: @Body() dto: RegisterDto
     *
     * Returns 200 OK by default. To return 201 Created, add @ResponseStatus(HttpStatus.CREATED).
     * We keep 200 to match NestJS behavior (NestJS defaults to 200 for POST as well, unless
     * @HttpCode(201) is specified — which it isn't in the original AuthController).
     */
    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest dto) {
        return authService.register(dto);
    }

    // ─── POST /api/auth/login ────────────────────────────────────

    /**
     * NestJS:
     *   @Post('login')
     *   @UseGuards(ThrottlerGuard)
     *   @Throttle({ short: { limit: 5, ttl: 60000 } })
     *   login(@Body() dto: LoginDto) {
     *     return this.authService.login(dto.email, dto.password);
     *   }
     *
     * Note: NestJS applies rate limiting via @Throttle (5 requests per 60s).
     * Spring Boot equivalent would be a rate-limiting library like Bucket4j or
     * Resilience4j. We skip it for Phase 3 and rely on the timing-safe login
     * in AuthService instead. Add rate limiting in a future phase if needed.
     */
    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest dto) {
        return authService.login(dto);
    }

    // ─── GET /api/auth/me ────────────────────────────────────────

    /**
     * NestJS:
     *   @UseGuards(JwtAuthGuard)
     *   @Get('me')
     *   me(@Request() req) {
     *     return req.user;
     *   }
     *
     * In NestJS, req.user is the object returned by JwtStrategy.validate().
     * In Spring, the equivalent is the Authentication principal stored by JwtAuthFilter.
     *
     * @AuthenticationPrincipal — injects the principal from SecurityContextHolder.
     *   Spring Security calls getAuthentication().getPrincipal() for us.
     *   We stored the User entity as the principal in JwtAuthFilter, so Spring
     *   injects it here as a User object.
     *
     * This route is protected by SecurityConfig (.anyRequest().authenticated()),
     * so a missing or invalid JWT results in 403 before this method is called.
     */
    @GetMapping("/me")
    public UserResponse me(@AuthenticationPrincipal User user) {
        return UserResponse.from(user);
    }
}
