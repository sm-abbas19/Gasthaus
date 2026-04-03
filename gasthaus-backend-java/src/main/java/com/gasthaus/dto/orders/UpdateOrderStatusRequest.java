package com.gasthaus.dto.orders;

import com.gasthaus.entity.enums.OrderStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Request body for PATCH /orders/:id/status (WAITER, KITCHEN, MANAGER only).
 *
 * NestJS equivalent: UpdateOrderStatusDto
 *   @IsEnum(OrderStatus) status: OrderStatus
 *
 * Spring Bean Validation doesn't have a built-in @IsEnum.
 * Instead, we use the Java enum type directly — Jackson will throw
 * HttpMessageNotReadableException (400) if the value isn't a valid enum constant.
 * No custom validator needed.
 */
public class UpdateOrderStatusRequest {

    @NotNull(message = "Status is required")
    private OrderStatus status;

    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }
}
