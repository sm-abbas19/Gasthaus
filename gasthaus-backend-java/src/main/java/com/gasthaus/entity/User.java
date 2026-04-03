package com.gasthaus.entity;

import com.gasthaus.entity.enums.Role;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps to the Prisma "model User" — represents a user account.
 *
 * ──────────────────────────────────────────────────────────────
 * ANNOTATION GUIDE
 * ──────────────────────────────────────────────────────────────
 *
 * @Entity
 *   Marks this class as a JPA-managed persistent object.
 *   NestJS equivalent: a TypeORM @Entity() decorator, or simply
 *   being referenced by a Prisma model.
 *   Hibernate will map every @Entity class to a database table.
 *
 * @Table(name = "users")
 *   Overrides the default table name. Without it, Hibernate would
 *   use the class name "User" — but "user" is a reserved keyword
 *   in PostgreSQL, so we explicitly name it "users".
 *
 * @Getter / @Setter (Lombok)
 *   Generates public getXxx() and setXxx() for every field.
 *   We avoid @Data because it generates equals/hashCode using ALL
 *   fields, which causes problems with bidirectional JPA relations
 *   (infinite recursion). Instead we use @EqualsAndHashCode(of="id").
 *
 * @NoArgsConstructor
 *   JPA requires a no-args constructor — it uses it to instantiate
 *   entities when loading from the database via reflection.
 *
 * @AllArgsConstructor + @Builder
 *   For convenient programmatic construction. Builder pattern lets
 *   you do: User.builder().name("Ali").email("...").build()
 */
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = {"orders", "reviews", "aiSessions"})
public class User {

    /**
     * @Id — designates this field as the primary key.
     *   Prisma equivalent: @id
     *
     * @GeneratedValue(strategy = GenerationType.UUID)
     *   Hibernate 6 (Spring Boot 3.x) natively generates UUID primary keys.
     *   Prisma equivalent: @default(uuid())
     *   UUID is better than auto-increment for distributed systems — IDs
     *   can be generated client-side without a round trip to the database.
     *
     * @Column(updatable = false)
     *   The primary key must never be updated after creation.
     */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * @Column(nullable = false)
     *   Maps to "name String" in Prisma — NOT NULL in SQL.
     *   Without this, Hibernate allows NULL by default.
     */
    @Column(nullable = false)
    private String name;

    /**
     * unique = true generates a UNIQUE constraint on this column.
     * Prisma equivalent: email String @unique
     */
    @Column(nullable = false, unique = true)
    private String email;

    /** Stores BCrypt hash — never the raw password. */
    @Column(nullable = false)
    private String password;

    /**
     * @Enumerated(EnumType.STRING)
     *   Stores the enum as a VARCHAR (e.g., "MANAGER") not an integer.
     *   Prisma handles this automatically; in JPA we must be explicit.
     *
     * @Column(columnDefinition = "varchar(20)")
     *   Gives PostgreSQL the exact column type. Without it Hibernate
     *   uses VARCHAR(255) which works but wastes space for short enums.
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "varchar(20)")
    @Builder.Default
    private Role role = Role.CUSTOMER;

    /**
     * @CreationTimestamp (Hibernate annotation)
     *   Automatically sets this field to the current timestamp when
     *   the entity is first persisted. Never updated after that.
     *   Prisma equivalent: createdAt DateTime @default(now())
     *
     * @Column(updatable = false) — enforces immutability at JPA level too.
     */
    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    /**
     * @UpdateTimestamp (Hibernate annotation)
     *   Automatically updates this field on every save/merge.
     *   Prisma equivalent: updatedAt DateTime @updatedAt
     */
    @UpdateTimestamp
    private LocalDateTime updatedAt;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS
    // ──────────────────────────────────────────────────────────

    /**
     * One User → Many Orders.
     *
     * @OneToMany — the "one" side of the relationship.
     *   mappedBy = "customer" means: "the Order entity owns this relationship
     *   via its 'customer' field — that's where the foreign key lives."
     *   Without mappedBy, JPA would create a separate join table.
     *
     * cascade = CascadeType.ALL — operations on User cascade to Orders.
     *   E.g., deleting a User deletes their Orders.
     *   Be careful with this in production — sometimes you want orphaned orders.
     *
     * fetch = FetchType.LAZY — orders are NOT loaded from DB unless accessed.
     *   This is the default for collections and almost always what you want.
     *   EAGER would load all orders every time you load a User — expensive.
     *   NestJS/Prisma uses lazy by default too (you explicitly include relations).
     *
     * @Builder.Default — required when Lombok @Builder is used with a field
     *   that has an initializer. Without it, the builder ignores the default.
     */
    // @JsonIgnore prevents circular serialization: Order → User.orders → Order → ...
    // NestJS avoids this by using Prisma's select (never returning User with orders attached).
    // In JPA, entities are rich objects — we annotate back-references to stop Jackson recursing.
    @JsonIgnore
    @OneToMany(mappedBy = "customer", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Order> orders = new ArrayList<>();

    @JsonIgnore
    @OneToMany(mappedBy = "customer", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Review> reviews = new ArrayList<>();

    @JsonIgnore
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<AiSession> aiSessions = new ArrayList<>();
}
