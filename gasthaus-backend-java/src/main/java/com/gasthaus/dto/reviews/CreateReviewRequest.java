package com.gasthaus.dto.reviews;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Request body for POST /reviews (CUSTOMER only).
 *
 * NestJS equivalent: CreateReviewDto
 *   @IsUUID() menuItemId: string
 *   @IsUUID() orderId: string
 *   @IsInt() @Min(1) @Max(5) rating: number
 *   @IsOptional() @IsString() comment?: string
 */
public class CreateReviewRequest {

    @NotNull(message = "Menu item ID is required")
    private UUID menuItemId;

    @NotNull(message = "Order ID is required")
    private UUID orderId;

    /**
     * @Min(1) @Max(5) — star rating between 1 and 5.
     * Bean Validation applies these at the field level.
     * NestJS: @IsInt() @Min(1) @Max(5) rating: number
     */
    @NotNull(message = "Rating is required")
    @Min(value = 1, message = "Rating must be at least 1")
    @Max(value = 5, message = "Rating must be at most 5")
    private Integer rating;

    /** Optional review comment. Null if omitted. */
    private String comment;

    public UUID getMenuItemId() { return menuItemId; }
    public void setMenuItemId(UUID menuItemId) { this.menuItemId = menuItemId; }

    public UUID getOrderId() { return orderId; }
    public void setOrderId(UUID orderId) { this.orderId = orderId; }

    public Integer getRating() { return rating; }
    public void setRating(Integer rating) { this.rating = rating; }

    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }
}
