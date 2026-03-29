package com.gasthaus.controller;

import com.gasthaus.dto.tables.CreateTableRequest;
import com.gasthaus.dto.tables.TableDetailResponse;
import com.gasthaus.dto.tables.TableStatsResponse;
import com.gasthaus.entity.RestaurantTable;
import com.gasthaus.service.TablesService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Restaurant table management endpoints.
 *
 * NestJS equivalent: TablesController in src/tables/tables.controller.ts
 *
 * Route ordering matters here:
 *   /stats must be declared BEFORE /{id} — otherwise Spring would try to
 *   parse "stats" as a UUID and fail. In Spring MVC, literal path segments
 *   ("stats", "number") take priority over path variables ({id}) automatically,
 *   so declaration order doesn't matter. Spring resolves by specificity.
 */
@RestController
@RequestMapping("/tables")
@RequiredArgsConstructor
public class TablesController {

    private final TablesService tablesService;

    /**
     * GET /api/tables — MANAGER, WAITER only
     *
     * NestJS: @Roles(Role.MANAGER, Role.WAITER) getAllTables()
     * Returns all tables ordered by tableNumber (floor plan data).
     */
    @GetMapping
    @PreAuthorize("hasRole('MANAGER')")
    public List<RestaurantTable> getAllTables() {
        return tablesService.getAllTables();
    }

    /**
     * GET /api/tables/stats — MANAGER, WAITER only
     *
     * NestJS: @Roles(Role.MANAGER, Role.WAITER) getTableStats()
     * Returns { total, occupied, available }.
     *
     * Declared before /{id} — Spring handles the ambiguity automatically
     * (literal "stats" beats path variable {id}) but explicit ordering is clearer.
     */
    @GetMapping("/stats")
    @PreAuthorize("hasRole('MANAGER')")
    public TableStatsResponse getTableStats() {
        return tablesService.getTableStats();
    }

    /**
     * GET /api/tables/number/:tableNumber — public (QR scan entry point)
     *
     * NestJS: @Get('number/:tableNumber') — no @UseGuards
     * Customers scan a QR code to reach their table's ordering page.
     * Path variable is int (auto-converted from String by Spring MVC).
     */
    @GetMapping("/number/{tableNumber}")
    public RestaurantTable getTableByNumber(@PathVariable int tableNumber) {
        return tablesService.getTableByNumber(tableNumber);
    }

    /**
     * GET /api/tables/:id — MANAGER, WAITER only
     *
     * Returns TableDetailResponse (table + active orders with full item/customer info).
     * NestJS: @Roles(Role.MANAGER, Role.WAITER) getTableById(@Param('id') id)
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    public TableDetailResponse getTableById(@PathVariable UUID id) {
        return tablesService.getTableById(id);
    }

    /**
     * POST /api/tables — MANAGER only
     *
     * NestJS:
     *   @Roles(Role.MANAGER) createTable(@Request() req, @Body() dto)
     *   const baseUrl = `${req.protocol}://${req.get('host')}`;
     *
     * Spring's HttpServletRequest provides the same protocol + host info.
     * HttpServletRequest is injected automatically by Spring MVC — no annotation needed.
     */
    @PostMapping
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public RestaurantTable createTable(@Valid @RequestBody CreateTableRequest dto,
                                       HttpServletRequest request) {
        // NestJS: `${req.protocol}://${req.get('host')}`
        // Spring: request.getScheme() = "http"/"https", request.getHeader("Host") = "localhost:8080"
        String baseUrl = request.getScheme() + "://" + request.getHeader("Host");
        return tablesService.createTable(dto, baseUrl);
    }

    /**
     * DELETE /api/tables/:id — MANAGER only
     *
     * NestJS: @Roles(Role.MANAGER) deleteTable(@Param('id') id)
     * Service catches DataIntegrityViolationException → 400 if table has orders.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTable(@PathVariable UUID id) {
        tablesService.deleteTable(id);
    }

    /**
     * PATCH /api/tables/:id/toggle — MANAGER, WAITER only
     *
     * NestJS: @Roles(Role.MANAGER, Role.WAITER) toggleOccupied(@Param('id') id)
     * Flips the isOccupied boolean on the table.
     */
    @PatchMapping("/{id}/toggle")
    @PreAuthorize("hasRole('MANAGER')")
    public RestaurantTable toggleOccupied(@PathVariable UUID id) {
        return tablesService.toggleOccupied(id);
    }
}
