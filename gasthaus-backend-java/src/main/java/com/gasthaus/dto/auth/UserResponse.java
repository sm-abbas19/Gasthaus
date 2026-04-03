package com.gasthaus.dto.auth;

import com.gasthaus.entity.User;
import com.gasthaus.entity.enums.Role;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Safe representation of a User — never includes the password field.
 *
 * NestJS equivalent: the Prisma select object used in UsersService:
 *   select: { id: true, name: true, email: true, role: true, createdAt: true }
 *
 * We use a Java record (Java 16+) instead of a class because:
 *   - Records are immutable by design — perfect for response DTOs
 *   - Compact syntax: constructor, getters, equals, hashCode, toString are auto-generated
 *   - Jackson serializes records natively (Spring Boot 3 / Jackson 2.12+)
 *
 * NestJS returned the user object as-is (minus password via destructuring).
 * Here we explicitly control the fields via this record.
 */
public record UserResponse(
        UUID id,
        String name,
        String email,
        Role role,
        LocalDateTime createdAt
) {
    /**
     * Factory method — converts a User entity to a safe DTO.
     *
     * NestJS equivalent: const { password: _, ...safeUser } = user;
     *
     * Calling UserResponse.from(user) is more readable than calling the constructor
     * directly and makes it clear where the data comes from.
     */
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRole(),
                user.getCreatedAt()
        );
    }
}
