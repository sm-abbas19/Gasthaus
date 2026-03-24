package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Maps to the Prisma "model Review".
 *
 * Key constraint from Prisma:
 *   @@unique([customerId, menuItemId, orderId])
 *   → a customer can review a menu item only once per order.
 *
 * In JPA this is declared as a @UniqueConstraint on @Table,
 * which generates a multi-column UNIQUE constraint in PostgreSQL.
 *
 * This entity is the OWNING SIDE of all three of its relationships
 * (it holds customer_id, menu_item_id, and order_id foreign keys).
 */
@Entity
@Table(
    name = "reviews",
    uniqueConstraints = {
        /**
         * @UniqueConstraint mirrors Prisma's @@unique([customerId, menuItemId, orderId]).
         * columnNames must match the actual FK column names defined in @JoinColumn below.
         * This enforces at the DB level that a customer can only review the same item
         * once per order — preventing duplicate review spam.
         */
        @UniqueConstraint(
            name = "uk_review_customer_item_order",
            columnNames = {"customer_id", "menu_item_id", "order_id"}
        )
    }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = {"customer", "menuItem", "order"})
public class Review {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * Star rating, typically 1–5. We enforce the range with Bean Validation
     * in the DTO (@Min(1) @Max(5)), not at the DB column level.
     */
    @Column(nullable = false)
    private Integer rating;

    /** Optional review text. Prisma: comment String? */
    @Column(columnDefinition = "text")
    private String comment;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS — owning side for all three
    // ──────────────────────────────────────────────────────────

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "menu_item_id", nullable = false)
    private MenuItem menuItem;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;
}
