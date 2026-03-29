package com.gasthaus.service;

import com.gasthaus.dto.orders.CreateOrderRequest;
import com.gasthaus.dto.orders.UpdateOrderStatusRequest;
import com.gasthaus.entity.MenuItem;
import com.gasthaus.entity.Order;
import com.gasthaus.entity.OrderItem;
import com.gasthaus.entity.RestaurantTable;
import com.gasthaus.entity.User;
import com.gasthaus.entity.enums.OrderStatus;
import com.gasthaus.repository.MenuItemRepository;
import com.gasthaus.repository.OrderRepository;
import com.gasthaus.repository.RestaurantTableRepository;
import com.gasthaus.websocket.OrdersGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Business logic for order lifecycle management.
 *
 * NestJS equivalent: OrdersService in src/orders/orders.service.ts
 *
 * Key Spring concept — @Transactional:
 *   NestJS used prisma.$transaction(async (tx) => { ... }) for atomic multi-table updates.
 *   Spring's @Transactional annotation is the direct equivalent — the entire annotated
 *   method runs inside a single database transaction. If any operation throws, the
 *   transaction rolls back automatically.
 *
 *   The @Transactional proxy wraps the method call:
 *     BEGIN TRANSACTION
 *       → method body runs
 *     COMMIT (or ROLLBACK on exception)
 *
 *   Unlike Prisma's $transaction which requires a special tx client, in Spring you
 *   simply use the repositories normally — Hibernate tracks everything in the same
 *   Persistence Context (the JPA session).
 */
@Service
@RequiredArgsConstructor
public class OrdersService {

    private final OrderRepository orderRepository;
    private final MenuItemRepository menuItemRepository;
    private final RestaurantTableRepository tableRepository;
    private final OrdersGateway gateway;

    // ─── Status flow validation ────────────────────────────────────

    /**
     * Defines the valid order status transitions.
     * NestJS equivalent: const STATUS_FLOW: Record<OrderStatus, OrderStatus | null>
     *
     * EnumMap — a Map implementation optimized for enum keys.
     * Backed by an array indexed by enum ordinal — O(1) lookup, no hashing overhead.
     * null value means "terminal state" (COMPLETED and CANCELLED have no next step).
     */
    private static final Map<OrderStatus, OrderStatus> STATUS_FLOW =
            new EnumMap<>(OrderStatus.class);

    static {
        STATUS_FLOW.put(OrderStatus.PENDING,    OrderStatus.CONFIRMED);
        STATUS_FLOW.put(OrderStatus.CONFIRMED,  OrderStatus.PREPARING);
        STATUS_FLOW.put(OrderStatus.PREPARING,  OrderStatus.READY);
        STATUS_FLOW.put(OrderStatus.READY,      OrderStatus.SERVED);
        STATUS_FLOW.put(OrderStatus.SERVED,     OrderStatus.COMPLETED);
        STATUS_FLOW.put(OrderStatus.COMPLETED,  null);  // terminal state
        STATUS_FLOW.put(OrderStatus.CANCELLED,  null);  // terminal state
    }

    // ─── Create Order ─────────────────────────────────────────────

    /**
     * NestJS: async createOrder(customerId: string, dto: CreateOrderDto)
     *
     * @Transactional — wraps the entire method in one DB transaction.
     *   NestJS equivalent: prisma.$transaction(async (tx) => { ... })
     *   All JPA saves within this method are part of the same atomic unit.
     *
     * Flow:
     *   1. Verify table exists
     *   2. Batch-fetch all requested menu items in one query
     *   3. Validate all items are available (replicate NestJS's foundIds check)
     *   4. Calculate totalAmount
     *   5. Build Order + OrderItem entities (cascade saves them together)
     *   6. Mark table as occupied
     *   7. Re-fetch the saved order with all relations for the response
     *   8. Emit WebSocket event
     */
    @Transactional
    public Order createOrder(User customer, CreateOrderRequest dto) {

        // ── Step 1: Verify table ──
        RestaurantTable table = tableRepository.findById(dto.getTableId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));

        if (table.getIsOccupied()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Table " + table.getTableNumber() + " is already occupied");
        }

        // ── Step 2: Batch-fetch menu items ──
        // NestJS: prisma.menuItem.findMany({ where: { id: { in: [...] }, isAvailable: true } })
        // One query for all items instead of N queries in a loop.
        Set<UUID> requestedIds = dto.getItems().stream()
                .map(i -> i.getMenuItemId())
                .collect(Collectors.toSet());

        List<MenuItem> foundItems = menuItemRepository.findByIdInAndIsAvailableTrue(requestedIds);

        // ── Step 3: Validate all items found and available ──
        // NestJS: const foundIds = new Set(menuItems.map(i => i.id));
        //         const missingIds = uniqueMenuItemIds.filter(id => !foundIds.has(id));
        Set<UUID> foundIds = foundItems.stream()
                .map(MenuItem::getId)
                .collect(Collectors.toSet());

        Set<UUID> missingIds = requestedIds.stream()
                .filter(id -> !foundIds.contains(id))
                .collect(Collectors.toSet());

        if (!missingIds.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "One or more items are unavailable or do not exist: " + missingIds);
        }

        // Build a lookup map for O(1) price access — NestJS: new Map(menuItems.map(item => [item.id, item]))
        Map<UUID, MenuItem> menuItemsById = foundItems.stream()
                .collect(Collectors.toMap(MenuItem::getId, item -> item));

        // ── Step 4: Calculate total ──
        // NestJS: dto.items.reduce((sum, i) => sum + menuItem.price * i.quantity, 0)
        double total = dto.getItems().stream()
                .mapToDouble(i -> menuItemsById.get(i.getMenuItemId()).getPrice() * i.getQuantity())
                .sum();

        // ── Step 5: Build Order + OrderItem entities ──
        // Cascade ALL on Order.items means saving the Order also saves all OrderItems.
        // NestJS equivalent: the nested create inside prisma.order.create({ data: { items: { create: [...] } } })
        Order order = Order.builder()
                .customer(customer)
                .table(table)
                .totalAmount(total)
                .build();

        List<OrderItem> orderItems = dto.getItems().stream()
                .map(itemReq -> {
                    MenuItem menuItem = menuItemsById.get(itemReq.getMenuItemId());
                    return OrderItem.builder()
                            .order(order)
                            .menuItem(menuItem)
                            .quantity(itemReq.getQuantity())
                            .unitPrice(menuItem.getPrice())  // snapshot price at order time
                            .notes(itemReq.getNotes())
                            .build();
                })
                .collect(Collectors.toList());

        order.setItems(orderItems);

        // save() cascades to OrderItems via CascadeType.ALL on Order.items
        orderRepository.save(order);

        // ── Step 6: Mark table occupied (same transaction) ──
        // NestJS: await tx.restaurantTable.update({ where: { id }, data: { isOccupied: true } })
        table.setIsOccupied(true);
        tableRepository.save(table);

        // ── Step 7: Re-fetch with full relations for the response ──
        // After save(), the in-memory entity has items but may have uninitialized proxies
        // for nested relations (menuItem inside each item, etc.).
        // Re-fetching with findByIdWithDetails() ensures Jackson can serialize everything.
        Order saved = orderRepository.findByIdWithDetails(order.getId())
                .orElseThrow();

        // ── Step 8: Emit WebSocket event ──
        // Called after the @Transactional method completes its work.
        // The emit is outside the DB transaction (SimpMessagingTemplate is not transactional).
        // NestJS: this.gateway.emitNewOrder(order)
        gateway.emitNewOrder(saved);

        return saved;
    }

    // ─── Read Orders ──────────────────────────────────────────────

    /**
     * NestJS:
     *   prisma.order.findMany({
     *     where: { status: { notIn: [COMPLETED, CANCELLED] } },
     *     include: { items: { include: { menuItem } }, customer, table },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * @Transactional(readOnly = true) — optimizes the transaction for reads:
     *   - No dirty-checking overhead (Hibernate won't track entity changes)
     *   - Some DB drivers can route reads to replicas
     *   NestJS has no equivalent (Prisma queries are always "read-only" when not inside $transaction)
     */
    @Transactional(readOnly = true)
    public List<Order> getAllOrders() {
        return orderRepository.findActiveOrdersWithDetails(
                List.of(OrderStatus.COMPLETED, OrderStatus.CANCELLED));
    }

    /**
     * NestJS: prisma.order.findUnique({ where: { id }, include: {...} })
     */
    @Transactional(readOnly = true)
    public Order getOrderById(UUID id) {
        return orderRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
    }

    /**
     * NestJS: prisma.order.findMany({ where: { customerId }, include: {...}, orderBy: { createdAt: 'desc' } })
     */
    @Transactional(readOnly = true)
    public List<Order> getMyOrders(UUID customerId) {
        return orderRepository.findByCustomerIdWithDetails(customerId);
    }

    // ─── Update Status ────────────────────────────────────────────

    /**
     * NestJS: async updateStatus(id: string, dto: UpdateOrderStatusDto)
     *
     * Validates the status transition against STATUS_FLOW, then updates the order.
     * If terminal (COMPLETED or CANCELLED), marks the table as available again.
     * Emits appropriate WebSocket event based on new status.
     */
    @Transactional
    public Order updateStatus(UUID id, UpdateOrderStatusRequest dto) {
        Order order = getOrderById(id);

        // ── Validate transition ──
        // NestJS: const allowedNext = STATUS_FLOW[order.status];
        //         if (dto.status !== CANCELLED && dto.status !== allowedNext) throw BadRequest
        OrderStatus allowedNext = STATUS_FLOW.get(order.getStatus());
        boolean isCancellation = dto.getStatus() == OrderStatus.CANCELLED;

        if (!isCancellation && dto.getStatus() != allowedNext) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    String.format("Cannot transition from %s to %s. Expected %s",
                            order.getStatus(), dto.getStatus(), allowedNext));
        }

        order.setStatus(dto.getStatus());
        orderRepository.save(order);

        // ── Free table when order is terminal ──
        // NestJS: if (status === COMPLETED || status === CANCELLED) table.isOccupied = false
        if (dto.getStatus() == OrderStatus.COMPLETED || isCancellation) {
            RestaurantTable table = order.getTable();
            table.setIsOccupied(false);
            tableRepository.save(table);
        }

        // Re-fetch for complete response
        Order updated = orderRepository.findByIdWithDetails(order.getId()).orElseThrow();

        // ── Emit event ──
        // Always emit order.status so staff dashboard/orders board updates.
        // Also emit order.ready when READY so customers can listen on that dedicated topic.
        gateway.emitOrderStatusUpdate(updated);
        if (dto.getStatus() == OrderStatus.READY) {
            gateway.emitOrderReady(updated);
        }

        return updated;
    }
}
