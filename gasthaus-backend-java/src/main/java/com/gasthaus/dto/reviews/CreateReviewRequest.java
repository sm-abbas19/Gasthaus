package com.gasthaus.dto.reviews;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Request body for POST /reviews (CUSTOMER only).
 *
 * Reviews are now ORDER-LEVEL — a customer rates the whole order experience.
 * menuItemId is removed; orderId + rating + optional comment is all that's needed.
 *
 * NestJS equivalent: CreateReviewDto (updated)
 *   @IsUUID() orderId: string
 *   @IsInt() @Min(1) @Max(5) rating: number
 *   @IsOptional() @IsString() comment?: string
 */
public class CreateReviewRequest {

    @NotNull(message = "Order ID is required")
    private UUID orderId;

    /**
     * Star rating 1–5. Bean Validation enforces the range before the service
     * layer is even reached, returning a 400 with a clear message if violated.
     */
    @NotNull(message = "Rating is required")
    @Min(value = 1, message = "Rating must be at least 1")
    @Max(value = 5, message = "Rating must be at most 5")
    private Integer rating;

    /** Optional written comment. Null if the customer only selects a star rating. */
    private String comment;

    public UUID getOrderId()              { return orderId; }
    public void setOrderId(UUID orderId)  { this.orderId = orderId; }

    public Integer getRating()              { return rating; }
    public void setRating(Integer rating)   { this.rating = rating; }

    public String getComment()              { return comment; }
    public void setComment(String comment)  { this.comment = comment; }
}
