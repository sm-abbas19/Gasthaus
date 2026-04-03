package com.gasthaus.entity;

import com.gasthaus.entity.enums.OrderStatus;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps to the Prisma "model Order".
 *
 * "Order" is NOT a reserved keyword in PostgreSQL, but "orders" is the
 * conventional plural so we use that as the table name.
 *
 * This entity is the OWNING SIDE of two Many-to-One relationships:
 *   - Order → User     (customer_id FK lives on this table)
 *   - Order → RestaurantTable  (table_id FK lives on this table)
 *
 * It is the INVERSE SIDE of:
 *   - Order ← OrderItem  (order_id FK lives on order_items table)
 *   - Order ← Review     (order_id FK lives on reviews table)
 */
@Entity
@Table(name = "orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = {"customer", "table", "items", "reviews"})
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * The order lifecycle status.
     * @Enumerated(EnumType.STRING) — stored as "PENDING", "CONFIRMED", etc.
     * @Builder.Default — ensures the default value works with the Builder pattern.
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "varchar(20)")
    @Builder.Default
    private OrderStatus status = OrderStatus.PENDING;

    /** Sum of all OrderItem prices. Calculated in the service layer, not DB. */
    @Column(nullable = false)
    private Double totalAmount;

    /** Optional special instructions from the customer (e.g. "no nuts, extra spicy"). */
    @Column(columnDefinition = "text")
    private String notes;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS — owning side (this table holds the FK)
    // ──────────────────────────────────────────────────────────

    /**
     * Many Orders → One Customer (User).
     *
     * @JoinColumn(name = "customer_id") — the FK column name in the orders table.
     * Prisma: customer User @relation(fields: [customerId], references: [id])
     *
     * optional = false means this FK cannot be NULL — an order always
     * has a customer. This generates a NOT NULL constraint.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    /**
     * Many Orders → One Table.
     * Prisma: table RestaurantTable @relation(fields: [tableId], references: [id])
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "table_id", nullable = false)
    private RestaurantTable table;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIPS — inverse side (FK lives on child table)
    // ──────────────────────────────────────────────────────────

    /** One Order → Many OrderItems. Items are deleted with the order. */
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<OrderItem> items = new ArrayList<>();

    /**
     * Status history — one entry per status transition, ordered chronologically.
     *
     * FetchType.EAGER: loaded automatically with every Order fetch.
     * @BatchSize(size = 50): when loading a list of orders, Hibernate batches the
     * history SELECTs into chunks of 50 (WHERE order_id IN (...)) instead of N
     * individual queries. This avoids the N+1 problem without a JOIN FETCH.
     *
     * Why not JOIN FETCH? — Adding a second JOIN FETCH on a List collection in the
     * same JPQL query as o.items causes a MultipleBagFetchException in Hibernate.
     * BatchSize sidesteps this by fetching histories in a separate batched query.
     */
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, fetch = FetchType.EAGER)
    @OrderBy("changedAt ASC")
    @org.hibernate.annotations.BatchSize(size = 50)
    @Builder.Default
    private List<OrderStatusHistory> statusHistory = new ArrayList<>();

    // Reviews are accessed via GET /reviews/order/:id — not included in order responses
    @JsonIgnore
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Review> reviews = new ArrayList<>();

    /**
     * A short display identifier derived from the UUID — first 8 hex characters,
     * upper-cased (e.g. "A1B2C3D4"). Consistent across all clients (Flutter app,
     * dashboard Kanban, modal, reviews page) so staff and customers always see the
     * same reference string.
     *
     * @Transient: not a DB column — computed on every serialisation.
     * @JsonProperty("orderNumber"): serialised as "orderNumber" so the existing
     * frontend code (which already reads order.orderNumber) picks it up without changes.
     */
    @Transient
    @JsonProperty("orderNumber")
    public String getDisplayOrderNumber() {
        return id != null ? id.toString().replace("-", "").substring(0, 8).toUpperCase() : null;
    }
}
