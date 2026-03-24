package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps to the Prisma "model RestaurantTable".
 *
 * "Table" is a reserved keyword in SQL, so we must name this entity's
 * table something else — "restaurant_tables" avoids any SQL conflicts.
 *
 * This entity holds no foreign keys; it's the inverse side of the
 * RestaurantTable ↔ Order relationship.
 */
@Entity
@Table(name = "restaurant_tables")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = "orders")
public class RestaurantTable {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * The physical table number on the restaurant floor.
     * Prisma: tableNumber Int @unique
     * unique = true → UNIQUE constraint in PostgreSQL.
     */
    @Column(nullable = false, unique = true)
    private Integer tableNumber;

    /**
     * QR code string (typically a URL like /table/5).
     * Prisma: qrCode String @unique
     */
    @Column(nullable = false, unique = true)
    private String qrCode;

    /**
     * Whether the table currently has seated guests.
     * Toggled by MANAGER/WAITER via PATCH /tables/:id/toggle.
     */
    @Column(nullable = false, columnDefinition = "boolean default false")
    @Builder.Default
    private Boolean isOccupied = false;

    /** One Table → Many Orders placed at that table. */
    @OneToMany(mappedBy = "table", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Order> orders = new ArrayList<>();
}
