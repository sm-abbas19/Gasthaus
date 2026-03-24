package com.gasthaus.entity.enums;

/**
 * Mirrors the Prisma "enum OrderStatus" exactly.
 *
 * This is the full lifecycle of an order:
 *   PENDING → CONFIRMED → PREPARING → READY → SERVED → COMPLETED
 *                                                      ↘ CANCELLED (any point)
 *
 * Stored as VARCHAR in PostgreSQL via @Enumerated(EnumType.STRING).
 */
public enum OrderStatus {
    PENDING,
    CONFIRMED,
    PREPARING,
    READY,
    SERVED,
    COMPLETED,
    CANCELLED
}
