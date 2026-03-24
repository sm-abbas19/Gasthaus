package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

/**
 * Maps to the Prisma "model OrderItem".
 *
 * This is a join entity — it sits between Order and MenuItem to
 * represent a line item: "2x Margherita Pizza at $12.99 each, no onions."
 *
 * It is the OWNING SIDE of both its relationships:
 *   - OrderItem → Order     (order_id FK lives here)
 *   - OrderItem → MenuItem  (menu_item_id FK lives here)
 *
 * This pattern is equivalent to a Prisma model with two @relation fields.
 */
@Entity
@Table(name = "order_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = {"order", "menuItem"})
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /** How many of this item were ordered. */
    @Column(nullable = false)
    private Integer quantity;

    /**
     * The price at time of ordering — snapshot of MenuItem.price.
     * Storing it here means price history is preserved even if the
     * menu item's price changes later. Same pattern is used in Prisma.
     */
    @Column(nullable = false)
    private Double unitPrice;

    /**
     * Optional special instructions: "no cilantro", "extra spicy".
     * Prisma: notes String?  → no nullable = false here.
     */
    @Column(columnDefinition = "text")
    private String notes;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS
    // ──────────────────────────────────────────────────────────

    /**
     * Many OrderItems → One Order.
     * This is the owning side — order_id FK column is defined here.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    /**
     * Many OrderItems → One MenuItem.
     * Allows us to look up what was ordered without doing a join to Order.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "menu_item_id", nullable = false)
    private MenuItem menuItem;
}
