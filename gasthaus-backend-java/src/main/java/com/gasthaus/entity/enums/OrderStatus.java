package com.gasthaus.entity.enums;

/**
 * Mirrors the Prisma "enum OrderStatus" exactly.
 *
 * This is the full lifecycle of an order:
 *   PENDING → CONFIRMED → PREPARING → READY → SERVED → PAID
 *                                                      ↘ CANCELLED (any point)
 *
 * PAID is the terminal success state — the dashboard marks an order PAID after
 * the customer settles the bill. The Flutter app maps PAID → "Done".
 * COMPLETED is kept for backwards compatibility with legacy data.
 *
 * Stored as VARCHAR in PostgreSQL via @Enumerated(EnumType.STRING).
 */
public enum OrderStatus {
    PENDING,
    CONFIRMED,
    PREPARING,
    READY,
    SERVED,
    PAID,
    COMPLETED,
    CANCELLED
}
