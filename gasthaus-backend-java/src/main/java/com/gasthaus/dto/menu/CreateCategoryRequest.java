package com.gasthaus.dto.menu;

import jakarta.validation.constraints.NotBlank;

/**
 * Request body for POST /menu/categories (MANAGER only).
 *
 * NestJS equivalent: CreateCategoryDto
 *   @IsString() name: string
 *   @IsOptional() @IsString() icon?: string
 */
public class CreateCategoryRequest {

    @NotBlank(message = "Category name is required")
    private String name;

    /** Optional icon identifier (e.g., "pizza", "coffee"). Null if omitted. */
    private String icon;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getIcon() { return icon; }
    public void setIcon(String icon) { this.icon = icon; }
}
