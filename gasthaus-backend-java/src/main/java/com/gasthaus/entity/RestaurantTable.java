package com.gasthaus.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
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
     * QR code data URI (data:image/png;base64,...).
     * Prisma: qrCode String @unique
     * Must be TEXT — base64-encoded PNG images far exceed VARCHAR(255).
     */
    @Column(nullable = false, unique = true, columnDefinition = "text")
    private String qrCode;

    /**
     * Whether the table currently has seated guests.
     * Toggled by MANAGER/WAITER via PATCH /tables/:id/toggle.
     */
    @Column(nullable = false, columnDefinition = "boolean default false")
    @Builder.Default
    private Boolean isOccupied = false;

    // Back-reference — suppressed in JSON to avoid Order → table → orders → Order cycle
    @JsonIgnore
    @OneToMany(mappedBy = "table", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Order> orders = new ArrayList<>();
}
