package com.gasthaus.dto.menu;

import jakarta.validation.constraints.Positive;

import java.util.UUID;

/**
 * Request body for PATCH /menu/items/:id (MANAGER only, multipart/form-data).
 *
 * NestJS equivalent: UpdateItemDto — all fields @IsOptional().
 * All fields here are nullable (no @NotNull) — the service applies only the
 * non-null fields, mirroring Prisma's partial update: { ...dto, ...(imageUrl && { imageUrl }) }
 */
public class UpdateItemRequest {

    private String name;
    private String description;

    @Positive(message = "Price must be greater than 0")
    private Double price;

    private UUID categoryId;
    private Boolean isAvailable;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Double getPrice() { return price; }
    public void setPrice(Double price) { this.price = price; }

    public UUID getCategoryId() { return categoryId; }
    public void setCategoryId(UUID categoryId) { this.categoryId = categoryId; }

    public Boolean getIsAvailable() { return isAvailable; }
    public void setIsAvailable(Boolean isAvailable) { this.isAvailable = isAvailable; }
}
