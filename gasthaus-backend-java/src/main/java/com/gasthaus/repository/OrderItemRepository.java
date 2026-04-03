package com.gasthaus.repository;

import com.gasthaus.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * Repository for OrderItem.
 *
 * NestJS equivalent: there is no dedicated Prisma call for OrderItems —
 * they are always accessed through their parent Order via Prisma's "include".
 *
 * In Spring, OrderItem entities are created/deleted via cascade from Order
 * (CascadeType.ALL on Order.items), so direct repository calls are rarely needed.
 *
 * This repository exists for completeness and for any future queries that
 * may need to access order items independently (e.g., reporting queries).
 */
@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, UUID> {
    // No custom methods needed — all access goes through OrderRepository's JOIN FETCHes.
}
