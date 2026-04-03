package com.gasthaus.dto.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request body for POST /ai/review-summary (public).
 *
 * NestJS equivalent: ReviewSummaryDto
 *   @IsString() menuItemName: string
 *   @IsArray() reviews: any[]
 */
public class ReviewSummaryRequest {

    @NotBlank(message = "Menu item name is required")
    private String menuItemName;

    @NotNull(message = "Reviews are required")
    private List<Object> reviews;

    public String getMenuItemName() { return menuItemName; }
    public void setMenuItemName(String menuItemName) { this.menuItemName = menuItemName; }

    public List<Object> getReviews() { return reviews; }
    public void setReviews(List<Object> reviews) { this.reviews = reviews; }
}
