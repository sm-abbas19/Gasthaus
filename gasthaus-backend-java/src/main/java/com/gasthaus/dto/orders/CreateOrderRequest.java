package com.gasthaus.dto.orders;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

/**
 * Request body for POST /orders (CUSTOMER only).
 *
 * NestJS equivalent: CreateOrderDto
 *   @IsUUID() tableId: string
 *   @IsArray() @ValidateNested({ each: true }) @Type(() => OrderItemDto) items: OrderItemDto[]
 *
 * Nested validation in Spring:
 *   @Valid on the items field triggers Bean Validation on each OrderItemRequest element.
 *   This is equivalent to NestJS's @ValidateNested({ each: true }) + @Type(() => OrderItemDto).
 *   The outer @Valid on the controller parameter triggers this chain.
 */
public class CreateOrderRequest {

    @NotNull(message = "Table ID is required")
    private UUID tableId;

    /** Optional order-level special instructions from the customer. */
    private String notes;

    @NotEmpty(message = "Order must contain at least one item")
    @Valid
    private List<OrderItemRequest> items;

    public UUID getTableId() { return tableId; }
    public void setTableId(UUID tableId) { this.tableId = tableId; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public List<OrderItemRequest> getItems() { return items; }
    public void setItems(List<OrderItemRequest> items) { this.items = items; }
}
