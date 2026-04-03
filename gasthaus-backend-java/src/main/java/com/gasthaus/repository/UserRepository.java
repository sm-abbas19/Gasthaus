package com.gasthaus.repository;

import com.gasthaus.entity.User;
import com.gasthaus.entity.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA repository for User.
 *
 * NestJS equivalent: PrismaService injected into UsersService.
 * Spring Data generates all SQL at startup — no boilerplate needed.
 *
 * JpaRepository<User, UUID> provides:
 *   save(user)          → INSERT / UPDATE
 *   findById(id)        → SELECT WHERE id = ?
 *   findAll()           → SELECT *
 *   delete(user)        → DELETE WHERE id = ?
 *   existsById(id)      → SELECT 1 WHERE id = ?
 *   ... and more
 *
 * Custom methods below are derived from the method name.
 * Spring Data parses the name and generates the JPQL automatically.
 */
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    /**
     * Prisma: prisma.user.findUnique({ where: { email } })
     *
     * Derived query: "findBy" + "Email" → SELECT u FROM User u WHERE u.email = ?1
     * Returns Optional because the user may not exist.
     */
    Optional<User> findByEmail(String email);

    /**
     * Prisma: check if existing != null after findByEmail.
     *
     * Spring Data generates: SELECT COUNT(*) > 0 WHERE email = ?1
     * More efficient than findByEmail when you only need a boolean.
     * Used in UsersService.create() to detect duplicate emails.
     */
    boolean existsByEmail(String email);

    /** Returns all users with the given roles, ordered by name. Used by MANAGER staff list. */
    List<User> findByRoleInOrderByNameAsc(List<Role> roles);
}
