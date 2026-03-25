package com.gasthaus.dto.tables;

import com.gasthaus.entity.Order;
import com.gasthaus.entity.RestaurantTable;

import java.util.List;
import java.util.UUID;

/**
 * Response for GET /tables/:id — a table with its active orders.
 *
 * NestJS equivalent: the object returned by prisma.restaurantTable.findUnique({
 *   include: { orders: { where: { status: { notIn: [...] } }, include: { items, customer } } }
 * })
 *
 * Because RestaurantTable.orders has @JsonIgnore (to prevent Order → table → orders → Order cycles),
 * we use this record to manually compose the response — same fields Prisma's include would produce.
 *
 * The JSON output mirrors NestJS: { id, tableNumber, qrCode, isOccupied, orders: [...] }
 */
public record TableDetailResponse(
        UUID id,
        Integer tableNumber,
        String qrCode,
        Boolean isOccupied,
        List<Order> orders
) {
    public static TableDetailResponse from(RestaurantTable table, List<Order> activeOrders) {
        return new TableDetailResponse(
                table.getId(),
                table.getTableNumber(),
                table.getQrCode(),
                table.getIsOccupied(),
                activeOrders
        );
    }
}
