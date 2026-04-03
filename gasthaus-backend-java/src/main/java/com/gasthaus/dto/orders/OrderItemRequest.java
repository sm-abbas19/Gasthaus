package com.gasthaus.dto.orders;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Represents one line item within a CreateOrderRequest.
 *
 * NestJS equivalent: OrderItemDto
 *   @IsUUID() menuItemId: string
 *   @IsInt() @Min(1) quantity: number
 *   @IsOptional() @IsString() notes?: string
 *
 * Nested validation in Spring:
 *   In NestJS, @ValidateNested({ each: true }) + @Type(() => OrderItemDto) validates
 *   each element of the items array.
 *   In Spring, @Valid on the parent class's items field triggers validation here
 *   when @Valid is applied to CreateOrderRequest in the controller.
 */
public class OrderItemRequest {

    @NotNull(message = "Menu item ID is required")
    private UUID menuItemId;

    @NotNull(message = "Quantity is required")
    @Min(value = 1, message = "Quantity must be at least 1")
    private Integer quantity;

    /** Optional special instructions — "no cilantro", "extra spicy". */
    private String notes;

    public UUID getMenuItemId() { return menuItemId; }
    public void setMenuItemId(UUID menuItemId) { this.menuItemId = menuItemId; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
}
