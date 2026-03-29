package com.gasthaus.controller;

import com.gasthaus.dto.menu.CreateCategoryRequest;
import com.gasthaus.dto.menu.CreateItemRequest;
import com.gasthaus.dto.menu.UpdateItemRequest;
import com.gasthaus.entity.MenuCategory;
import com.gasthaus.entity.MenuItem;
import com.gasthaus.service.MenuService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/**
 * Menu endpoints: categories and items.
 *
 * NestJS equivalent: MenuController in src/menu/menu.controller.ts
 *
 * Role protection mapping:
 *   NestJS: @UseGuards(JwtAuthGuard, RolesGuard) + @Roles(Role.MANAGER)
 *   Spring:  @PreAuthorize("hasRole('MANAGER')")
 *
 * @PreAuthorize is evaluated by Spring Security's AOP proxy BEFORE the method runs.
 * It uses the GrantedAuthority set in JwtAuthFilter: "ROLE_MANAGER" etc.
 * hasRole('MANAGER') checks for "ROLE_MANAGER" in the authority list (Spring adds the prefix).
 *
 * Public routes (no auth needed) are already configured in SecurityConfig.permitAll().
 * @PreAuthorize adds the fine-grained role check on top of authentication.
 */
@RestController
@RequestMapping("/menu")
@RequiredArgsConstructor
public class MenuController {

    private final MenuService menuService;

    // ─── Categories ───────────────────────────────────────────────

    /**
     * GET /api/menu/categories — public
     * NestJS: @Get('categories') getCategories() { return this.menuService.getCategories(); }
     *
     * Returns categories with their available items.
     * Response is served from the "menu:categories" cache after the first call.
     */
    @GetMapping("/categories")
    public List<MenuCategory> getCategories(
            @RequestParam(value = "all", defaultValue = "false") boolean all) {
        return all ? menuService.getCategoriesWithAllItems() : menuService.getCategories();
    }

    /**
     * POST /api/menu/categories — MANAGER only
     * NestJS: @UseGuards(JwtAuthGuard, RolesGuard) @Roles(Role.MANAGER) @Post('categories')
     *
     * @RequestBody for JSON — categories have no file upload.
     * @ResponseStatus(CREATED) returns HTTP 201 (REST convention for resource creation).
     * NestJS defaults to 200 for POST unless @HttpCode(201) is added.
     */
    @PostMapping("/categories")
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public MenuCategory createCategory(@Valid @RequestBody CreateCategoryRequest dto) {
        return menuService.createCategory(dto);
    }

    /**
     * DELETE /api/menu/categories/:id — MANAGER only
     * NestJS: @Delete('categories/:id')
     *
     * @PathVariable("id") — extracts the {id} segment from the URL.
     * NestJS equivalent: @Param('id') id: string
     *
     * @ResponseStatus(NO_CONTENT) — 204 response, no body. REST convention for DELETE.
     */
    @DeleteMapping("/categories/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@PathVariable UUID id) {
        menuService.deleteCategory(id);
    }

    // ─── Items ────────────────────────────────────────────────────

    /**
     * GET /api/menu/items — public
     * NestJS: @Get('items') getItems()
     */
    @GetMapping("/items")
    public List<MenuItem> getItems() {
        return menuService.getItems();
    }

    /**
     * GET /api/menu/items/:id — public
     * NestJS: @Get('items/:id') getItemById(@Param('id') id: string)
     */
    @GetMapping("/items/{id}")
    public MenuItem getItemById(@PathVariable UUID id) {
        return menuService.getItemById(id);
    }

    /**
     * POST /api/menu/items — MANAGER only, multipart/form-data
     *
     * NestJS:
     *   @Post('items')
     *   @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
     *   createItem(@Body() dto: CreateItemDto, @UploadedFile() image?: Express.Multer.File)
     *
     * Spring equivalent:
     *   @ModelAttribute — binds form fields to CreateItemRequest (replaces @Body)
     *   @RequestParam("image") MultipartFile — the file part (replaces @UploadedFile)
     *
     * Why @ModelAttribute instead of @RequestBody?
     *   multipart/form-data encodes fields as key=value pairs, not JSON.
     *   @RequestBody only reads JSON. @ModelAttribute reads form fields AND triggers
     *   Bean Validation when combined with @Valid — same as NestJS's ValidationPipe.
     *
     * The "image" field is optional — Spring sets it to null (or empty MultipartFile)
     * if no file is provided. The service checks image.isEmpty() before uploading.
     */
    @PostMapping("/items")
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public MenuItem createItem(
            @Valid @ModelAttribute CreateItemRequest dto,
            @RequestParam(value = "image", required = false) MultipartFile image) {
        return menuService.createItem(dto, image);
    }

    /**
     * PATCH /api/menu/items/:id — MANAGER only, multipart/form-data
     *
     * NestJS:
     *   @Patch('items/:id')
     *   @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
     *   updateItem(@Param('id') id, @Body() dto, @UploadedFile() image?)
     *
     * UpdateItemRequest has all fields optional — partial update pattern.
     * The service applies only the non-null fields to the entity.
     */
    @PatchMapping("/items/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    public MenuItem updateItem(
            @PathVariable UUID id,
            @Valid @ModelAttribute UpdateItemRequest dto,
            @RequestParam(value = "image", required = false) MultipartFile image) {
        return menuService.updateItem(id, dto, image);
    }

    /**
     * DELETE /api/menu/items/:id — MANAGER only
     * NestJS: @Delete('items/:id') deleteItem(@Param('id') id: string)
     */
    @DeleteMapping("/items/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteItem(@PathVariable UUID id) {
        menuService.deleteItem(id);
    }

    /**
     * PATCH /api/menu/items/:id/toggle — MANAGER only
     * NestJS: @Patch('items/:id/toggle') toggleAvailability(@Param('id') id: string)
     *
     * No body needed — flips the current isAvailable boolean in the service.
     */
    @PatchMapping("/items/{id}/toggle")
    @PreAuthorize("hasRole('MANAGER')")
    public MenuItem toggleAvailability(@PathVariable UUID id) {
        return menuService.toggleAvailability(id);
    }
}
