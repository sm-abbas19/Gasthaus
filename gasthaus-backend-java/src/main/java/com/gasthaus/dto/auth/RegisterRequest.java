package com.gasthaus.dto.auth;

import com.gasthaus.entity.enums.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Request body for POST /auth/register.
 *
 * NestJS equivalent: RegisterDto with class-validator decorators.
 * Spring equivalent: a plain class (or record) with Jakarta Bean Validation annotations.
 *
 * The @Valid annotation on the controller parameter triggers validation.
 * If any constraint fails, Spring throws MethodArgumentNotValidException → 400 Bad Request.
 * NestJS equivalent: ValidationPipe with whitelist: true in main.ts.
 *
 * We use a class (not a record) so Jackson can deserialize it
 * without needing extra configuration (records need @JsonCreator or a custom module).
 *
 * The `role` field is optional — defaults to CUSTOMER in UserService if null.
 * NestJS equivalent: @IsOptional() @IsEnum(Role) role?: Role
 */
public class RegisterRequest {

    /**
     * @NotBlank — rejects null, empty string, and whitespace-only strings.
     * NestJS: @IsString()
     */
    @NotBlank(message = "Name is required")
    private String name;

    /**
     * @Email — validates RFC-compliant email format.
     * NestJS: @IsEmail()
     */
    @Email(message = "Invalid email address")
    @NotBlank(message = "Email is required")
    private String email;

    /**
     * @Size(min = 6) — minimum length constraint.
     * NestJS: @MinLength(6)
     */
    @NotBlank(message = "Password is required")
    @Size(min = 6, message = "Password must be at least 6 characters")
    private String password;

    /**
     * Optional role. Null is allowed here — UserService defaults to CUSTOMER.
     * NestJS: @IsOptional() @IsEnum(Role) role?: Role
     *
     * No @NotNull so Jackson sets it to null when omitted from the request body.
     */
    private Role role;

    // ── Standard getters/setters (needed by Jackson for deserialization) ──
    // We avoid Lombok @Data here because this is a DTO — no entity-style concerns.

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public Role getRole() { return role; }
    public void setRole(Role role) { this.role = role; }
}
