package com.gasthaus.entity.enums;

/**
 * Mirrors the Prisma "enum Role" exactly.
 *
 * In Java, enums are first-class types — not just string unions.
 * When stored in the database via @Enumerated(EnumType.STRING) on the
 * entity field, Hibernate saves the name() of the enum constant
 * (e.g., "MANAGER") rather than its ordinal position (0, 1, 2...).
 *
 * ALWAYS use EnumType.STRING in production — ordinal-based storage
 * breaks the moment you reorder or add values to this enum.
 */
public enum Role {
    CUSTOMER,
    WAITER,
    KITCHEN,
    MANAGER
}
