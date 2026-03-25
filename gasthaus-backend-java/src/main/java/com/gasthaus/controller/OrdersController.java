package com.gasthaus.controller;

import com.gasthaus.dto.orders.CreateOrderRequest;
import com.gasthaus.dto.orders.UpdateOrderStatusRequest;
import com.gasthaus.entity.Order;
import com.gasthaus.entity.User;
import com.gasthaus.service.OrdersService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Order lifecycle endpoints.
 *
 * NestJS equivalent: OrdersController in src/orders/orders.controller.ts
 *
 * All routes require authentication (@UseGuards(JwtAuthGuard) on the NestJS class).
 * In Spring, SecurityConfig already gates all non-public routes with authentication.
 * @PreAuthorize adds the role check on top.
 *
 * Role mapping from NestJS:
 *   @Roles(Role.CUSTOMER)               → @PreAuthorize("hasRole('CUSTOMER')")
 *   @Roles(Role.WAITER, Role.KITCHEN, Role.MANAGER) → @PreAuthorize("hasAnyRole('WAITER','KITCHEN','MANAGER')")
 *   No @Roles on getMyOrders / getOrderById → any authenticated user
 *
 * @AuthenticationPrincipal User user — injects the User entity set as principal
 * in JwtAuthFilter. Replaces NestJS's @Request() req + req.user.id.
 */
@RestController
@RequestMapping("/orders")
@RequiredArgsConstructor
public class OrdersController {

    private final OrdersService ordersService;

    /**
     * POST /api/orders — CUSTOMER only
     *
     * NestJS:
     *   @Post()
     *   @Roles(Role.CUSTOMER) @UseGuards(RolesGuard)
     *   createOrder(@Request() req, @Body() dto: CreateOrderDto) {
     *     return this.ordersService.createOrder(req.user.id, dto);
     *   }
     *
     * We pass the full User entity (not just the ID) since OrdersService builds
     * the Order entity with customer = user. This avoids a redundant DB lookup.
     */
    @PostMapping
    @PreAuthorize("hasRole('CUSTOMER')")
    @ResponseStatus(HttpStatus.CREATED)
    public Order createOrder(@AuthenticationPrincipal User user,
                             @Valid @RequestBody CreateOrderRequest dto) {
        return ordersService.createOrder(user, dto);
    }

    /**
     * GET /api/orders — WAITER, KITCHEN, MANAGER only (active orders for staff)
     *
     * NestJS:
     *   @Get()
     *   @Roles(Role.WAITER, Role.KITCHEN, Role.MANAGER) @UseGuards(RolesGuard)
     *   getAllOrders()
     *
     * hasAnyRole() is the multi-role equivalent of NestJS's @Roles() with multiple values.
     */
    @GetMapping
    @PreAuthorize("hasAnyRole('WAITER','KITCHEN','MANAGER')")
    public List<Order> getAllOrders() {
        return ordersService.getAllOrders();
    }

    /**
     * GET /api/orders/my — any authenticated user (customer views their own orders)
     *
     * NestJS: @Get('my') getMyOrders(@Request() req)
     *
     * IMPORTANT: Spring maps @GetMapping("/my") before @GetMapping("/{id}") only if
     * declared first. The literal path "/my" has higher priority than the path variable
     * "/{id}" because Spring evaluates exact matches before patterns.
     * Always declare literal routes before path-variable routes.
     */
    @GetMapping("/my")
    public List<Order> getMyOrders(@AuthenticationPrincipal User user) {
        return ordersService.getMyOrders(user.getId());
    }

    /**
     * GET /api/orders/:id — any authenticated user
     *
     * NestJS: @Get(':id') getOrderById(@Param('id') id: string)
     */
    @GetMapping("/{id}")
    public Order getOrderById(@PathVariable UUID id) {
        return ordersService.getOrderById(id);
    }

    /**
     * PATCH /api/orders/:id/status — WAITER, KITCHEN, MANAGER only
     *
     * NestJS: @Patch(':id/status') @Roles(WAITER, KITCHEN, MANAGER) @UseGuards(RolesGuard)
     *   updateStatus(@Param('id') id: string, @Body() dto: UpdateOrderStatusDto)
     */
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('WAITER','KITCHEN','MANAGER')")
    public Order updateStatus(@PathVariable UUID id,
                              @Valid @RequestBody UpdateOrderStatusRequest dto) {
        return ordersService.updateStatus(id, dto);
    }
}
