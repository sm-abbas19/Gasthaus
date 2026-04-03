package com.gasthaus.dto.menu;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.util.UUID;

/**
 * Request body for POST /menu/items (MANAGER only, multipart/form-data).
 *
 * NestJS equivalent: CreateItemDto with class-validator + @Type(() => Number) for price.
 *
 * Why multipart instead of JSON?
 * The request can include an image file alongside the item data.
 * multipart/form-data is the only content type that supports mixed file + text fields.
 * NestJS uses multer's memoryStorage() to buffer the file; Spring handles multipart natively.
 *
 * Why @ModelAttribute (not @RequestBody)?
 * @RequestBody reads raw JSON. @ModelAttribute reads form fields, which is what
 * multipart/form-data sends. Spring auto-converts string form values to their Java types
 * (so "9.99" → Double for the price field). No @Type(() => Number) needed like in NestJS.
 *
 * The image file itself is a separate @RequestParam("image") MultipartFile on the controller.
 */
public class CreateItemRequest {

    @NotBlank(message = "Item name is required")
    private String name;

    /** Optional description text. */
    private String description;

    /**
     * @Positive ensures price > 0.
     * @NotNull ensures it's present in the form data.
     * Spring converts the form string "9.99" → Double automatically.
     * NestJS: @Type(() => Number) @IsNumber() price: number
     */
    @NotNull(message = "Price is required")
    @Positive(message = "Price must be greater than 0")
    private Double price;

    /** UUID of the category this item belongs to. */
    @NotNull(message = "Category ID is required")
    private UUID categoryId;

    /**
     * Optional — defaults to true in the MenuItem entity (@Builder.Default).
     * NestJS: @IsOptional() @IsBoolean() isAvailable?: boolean
     */
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
