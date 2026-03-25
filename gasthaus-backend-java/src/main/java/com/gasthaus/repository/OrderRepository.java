package com.gasthaus.repository;

import com.gasthaus.entity.Order;
import com.gasthaus.entity.enums.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Repository for Order.
 *
 * NestJS equivalent: prisma.order.findMany / findUnique / create / update
 *
 * Important: Order has @ManyToOne relationships (no direct customerId / tableId fields).
 * Spring Data JPA resolves nested properties automatically:
 *   "Customer_Id" → customer.id  (underscore used to disambiguate traversal)
 *   "Table_Id"    → table.id
 *
 * The @Query methods below use JOIN FETCH to eagerly load nested collections
 * in one query, mirroring Prisma's "include" option.
 */
@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {

    /**
     * Prisma:
     *   prisma.order.findMany({
     *     where: { customerId },
     *     include: { items: { include: { menuItem: true } }, table: true },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * Used in OrdersService.getMyOrders() for the customer's order history.
     *
     * JPQL JOIN FETCH loads items + menuItem + table in a single SQL query.
     * DISTINCT prevents duplicate Order rows from the join.
     *
     * Spring Data resolves "Customer_Id" as: o.customer.id = :customerId
     */
    @Query("""
            SELECT DISTINCT o FROM Order o
            JOIN FETCH o.customer c
            JOIN FETCH o.table t
            LEFT JOIN FETCH o.items i
            LEFT JOIN FETCH i.menuItem
            WHERE c.id = :customerId
            ORDER BY o.createdAt DESC
            """)
    List<Order> findByCustomerIdWithDetails(@Param("customerId") UUID customerId);

    /**
     * Prisma:
     *   prisma.order.findMany({
     *     where: { status: { notIn: [COMPLETED, CANCELLED] } },
     *     include: { items: { include: { menuItem: true } }, customer: true, table: true },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * Used in OrdersService.getAllOrders() for the staff Kanban board.
     * "Active" orders = anything that hasn't been completed or cancelled.
     */
    @Query("""
            SELECT DISTINCT o FROM Order o
            JOIN FETCH o.customer
            JOIN FETCH o.table
            LEFT JOIN FETCH o.items i
            LEFT JOIN FETCH i.menuItem
            WHERE o.status NOT IN :statuses
            ORDER BY o.createdAt DESC
            """)
    List<Order> findActiveOrdersWithDetails(@Param("statuses") Collection<OrderStatus> statuses);

    /**
     * Prisma:
     *   prisma.order.findUnique({
     *     where: { id },
     *     include: { items: { include: { menuItem: true } }, customer: true, table: true }
     *   })
     *
     * Used in OrdersService.getOrderById() and as the base for updateStatus().
     * Returns Optional — caller throws NotFoundException if empty.
     */
    @Query("""
            SELECT o FROM Order o
            JOIN FETCH o.customer
            JOIN FETCH o.table
            LEFT JOIN FETCH o.items i
            LEFT JOIN FETCH i.menuItem
            WHERE o.id = :id
            """)
    java.util.Optional<Order> findByIdWithDetails(@Param("id") UUID id);

    /**
     * Used in TablesService to find active (non-completed) orders for a table.
     * Prisma:
     *   orders: { where: { status: { notIn: ['COMPLETED', 'CANCELLED'] } } }
     *   (inside a RestaurantTable include)
     *
     * Spring Data traverses: table.id → Table_Id
     */
    List<Order> findByTable_IdAndStatusNotIn(UUID tableId, Collection<OrderStatus> statuses);

    /**
     * Used in TablesService.getTableById() to load a table's active orders with
     * all nested relations eagerly fetched in one query.
     * NestJS: orders: { include: { items: { include: { menuItem } }, customer } }
     */
    @Query("""
            SELECT DISTINCT o FROM Order o
            JOIN FETCH o.customer
            JOIN FETCH o.table
            LEFT JOIN FETCH o.items i
            LEFT JOIN FETCH i.menuItem
            WHERE o.table.id = :tableId AND o.status NOT IN :statuses
            ORDER BY o.createdAt DESC
            """)
    List<Order> findActiveByTableIdWithDetails(
            @Param("tableId") UUID tableId,
            @Param("statuses") Collection<OrderStatus> statuses);
}
