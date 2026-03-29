package com.gasthaus.service;

import com.gasthaus.entity.User;
import com.gasthaus.entity.enums.Role;
import com.gasthaus.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Business logic for User operations.
 *
 * NestJS equivalent: UsersService in src/users/users.service.ts
 *
 * @Service — marks this as a Spring-managed service bean.
 *   NestJS equivalent: @Injectable()
 *   Spring scans for @Service (and @Component, @Repository, @Controller)
 *   and registers them in the application context automatically.
 *
 * @RequiredArgsConstructor (Lombok) — generates a constructor for all final fields.
 *   Spring uses constructor injection by default when there is exactly one constructor.
 *   NestJS equivalent: declaring dependencies in the constructor:
 *     constructor(private prisma: PrismaService) {}
 */
@Service
@RequiredArgsConstructor
public class UserService {

    /**
     * Spring Data JPA repository — auto-implemented at startup.
     * NestJS equivalent: private readonly prisma: PrismaService
     */
    private final UserRepository userRepository;

    /**
     * BCryptPasswordEncoder bean declared in SecurityConfig.
     * NestJS equivalent: import * as bcrypt from 'bcrypt';
     * (used here for hashing during create, and in AuthService for comparison)
     */
    private final PasswordEncoder passwordEncoder;

    // ─── findByEmail ────────────────────────────────────────────

    /**
     * NestJS: this.prisma.user.findUnique({ where: { email } })
     *
     * Returns Optional so callers explicitly handle the "not found" case.
     * The JWT filter and AuthService both use this.
     */
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    // ─── findById ───────────────────────────────────────────────

    /**
     * NestJS: this.prisma.user.findUnique({ where: { id }, select: { id, name, email, role, createdAt } })
     *
     * Returns the full User entity. The caller (JwtAuthFilter, AuthController)
     * is responsible for converting to UserResponse DTO if the password must be hidden.
     *
     * JpaRepository.findById() returns Optional<User> natively.
     */
    public Optional<User> findById(UUID id) {
        return userRepository.findById(id);
    }

    // ─── create ─────────────────────────────────────────────────

    /**
     * NestJS:
     *   const existing = await this.findByEmail(email);
     *   if (existing) throw new ConflictException('Email already in use');
     *   const hashed = await bcrypt.hash(password, 10);
     *   return this.prisma.user.create({ data: { name, email, password: hashed, role } })
     *
     * Spring exception mapping:
     *   ConflictException (NestJS 409) → ResponseStatusException(HttpStatus.CONFLICT)
     *
     * ResponseStatusException is Spring's general-purpose HTTP exception.
     * Later phases may introduce a @ControllerAdvice for cleaner error responses,
     * but ResponseStatusException works fine for now.
     */
    /** Returns all KITCHEN and MANAGER accounts, ordered by name. */
    public List<User> getStaff() {
        return userRepository.findByRoleInOrderByNameAsc(List.of(Role.KITCHEN, Role.MANAGER));
    }

    public User create(String name, String email, String password, Role role) {
        // Duplicate email check — same logic as NestJS
        if (userRepository.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already in use");
        }

        // Hash the password with BCrypt (cost factor 10 — same as NestJS's bcrypt.hash(pw, 10))
        String hashedPassword = passwordEncoder.encode(password);

        // Build and persist the User entity using Lombok's builder
        User user = User.builder()
                .name(name)
                .email(email)
                .password(hashedPassword)
                .role(role != null ? role : Role.CUSTOMER) // default to CUSTOMER if not provided
                .build();

        // userRepository.save() → INSERT if entity is new (no id set), UPDATE if id exists
        // Hibernate uses GenerationType.UUID to assign the id before inserting.
        return userRepository.save(user);
    }
}
