package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps to the Prisma "model MenuItem".
 *
 * This entity is the OWNING SIDE of the Category ↔ MenuItem relation
 * because it holds the category_id foreign key column in the DB.
 *
 * It is also the OWNING SIDE of the MenuItem ↔ OrderItem relation
 * (OrderItem holds menu_item_id) and MenuItem ↔ Review (Review holds menu_item_id).
 */
@Entity
@Table(name = "menu_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = {"category", "orderItems", "reviews"})
public class MenuItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false)
    private String name;

    /** Nullable — Prisma: description String? */
    @Column(columnDefinition = "text")
    private String description;

    /** Prisma: price Float → Java: Double (or BigDecimal for money in production) */
    @Column(nullable = false)
    private Double price;

    /** Nullable — URL to Cloudinary image */
    private String imageUrl;

    /**
     * @Column with columnDefinition sets the exact SQL type.
     * Default true — Prisma: isAvailable Boolean @default(true)
     * @Builder.Default required for Lombok to respect the initializer.
     */
    @Column(nullable = false, columnDefinition = "boolean default true")
    @Builder.Default
    private Boolean isAvailable = true;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS
    // ──────────────────────────────────────────────────────────

    /**
     * Many MenuItems → One Category.
     *
     * @ManyToOne — the "many" side; this entity holds the foreign key.
     * fetch = FetchType.LAZY — don't auto-join category on every query.
     *   Without this, every MenuItem load would also fetch its Category.
     *   NestJS/Prisma: you'd explicitly { include: { category: true } }.
     *
     * @JoinColumn(name = "category_id")
     *   Tells Hibernate the FK column name in this table.
     *   Without @JoinColumn, Hibernate auto-names it "category_id" anyway,
     *   but being explicit is better documentation.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private MenuCategory category;

    @OneToMany(mappedBy = "menuItem", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<OrderItem> orderItems = new ArrayList<>();

    @OneToMany(mappedBy = "menuItem", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Review> reviews = new ArrayList<>();
}
