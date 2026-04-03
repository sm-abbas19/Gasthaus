package com.gasthaus.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.gasthaus.entity.enums.OrderStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Tracks each status transition for an order.
 *
 * Every time an order moves to a new status (PENDING → CONFIRMED → PREPARING etc.),
 * a new row is inserted here with a timestamp. This lets the dashboard show the
 * exact time each stage was reached — equivalent to a Prisma audit log pattern.
 *
 * NestJS equivalent: there was no status history in the NestJS version.
 * In a NestJS/Prisma app you'd add a separate "OrderStatusHistory" model with
 * @relation fields pointing back to the Order.
 *
 * This is the OWNING SIDE of the Order relationship (order_id FK lives here),
 * same pattern as OrderItem.
 */
@Entity
@Table(name = "order_status_history")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderStatusHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * The order this history entry belongs to.
     * @JsonIgnore breaks the cycle: Order.statusHistory → OrderStatusHistory.order → Order → ...
     */
    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    /**
     * The status that the order transitioned TO at this point in time.
     * The first entry for a new order will always be PENDING.
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    /**
     * When this transition happened.
     * @CreationTimestamp sets this automatically on INSERT — we never update history rows.
     */
    @CreationTimestamp
    @Column(updatable = false, nullable = false)
    private LocalDateTime changedAt;
}
