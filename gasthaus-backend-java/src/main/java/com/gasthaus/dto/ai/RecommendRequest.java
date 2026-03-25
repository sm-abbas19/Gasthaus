package com.gasthaus.dto.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request body for POST /ai/recommend (CUSTOMER only).
 *
 * NestJS equivalent: RecommendDto
 *   @IsString() message: string
 *   @IsArray() menuItems: any[]
 *
 * Note: the controller adds `userId` from the authenticated user before
 * forwarding to FastAPI — it is NOT part of this client-facing DTO.
 * NestJS does the same: dto only has message + menuItems, userId comes from req.user.id.
 *
 * menuItems is List<Object> because the FastAPI service accepts arbitrary item shapes.
 * NestJS uses any[] for the same reason.
 */
public class RecommendRequest {

    @NotBlank(message = "Message is required")
    private String message;

    @NotNull(message = "Menu items are required")
    private List<Object> menuItems;

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public List<Object> getMenuItems() { return menuItems; }
    public void setMenuItems(List<Object> menuItems) { this.menuItems = menuItems; }
}
