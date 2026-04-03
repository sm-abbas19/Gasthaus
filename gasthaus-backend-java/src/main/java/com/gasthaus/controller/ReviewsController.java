package com.gasthaus.controller;

import com.gasthaus.dto.reviews.CreateReviewRequest;
import com.gasthaus.dto.reviews.ItemReviewsResponse;
import com.gasthaus.entity.Review;
import com.gasthaus.entity.User;
import com.gasthaus.service.ReviewsService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Review endpoints.
 *
 * NestJS equivalent: ReviewsController in src/reviews/reviews.controller.ts
 *
 * Route ordering matters in Spring MVC:
 *   @GetMapping — GET /reviews (all reviews, MANAGER)
 *   @GetMapping("/item/{menuItemId}") — public
 *   @GetMapping("/order/{orderId}") — CUSTOMER
 *
 * Spring routes by specificity — literal segments beat path variables,
 * so "/item/{menuItemId}" correctly beats "/{anything}" if we had one.
 * No ordering issue here since all three have distinct prefixes.
 */
@RestController
@RequestMapping("/reviews")
@RequiredArgsConstructor
public class ReviewsController {

    private final ReviewsService reviewsService;

    /**
     * POST /api/reviews — CUSTOMER only
     *
     * NestJS:
     *   @UseGuards(JwtAuthGuard, RolesGuard) @Roles(Role.CUSTOMER)
     *   @Post() createReview(@Request() req, @Body() dto: CreateReviewDto)
     */
    @PostMapping
    @PreAuthorize("hasRole('CUSTOMER')")
    @ResponseStatus(HttpStatus.CREATED)
    public Review createReview(@AuthenticationPrincipal User user,
                               @Valid @RequestBody CreateReviewRequest dto) {
        return reviewsService.createReview(user, dto);
    }

    /**
     * GET /api/reviews/item/:menuItemId — public (no auth)
     *
     * Returns { menuItemId, menuItemName, averageRating, totalReviews, reviews[] }
     * NestJS: @Get('item/:menuItemId') — no @UseGuards
     */
    @GetMapping("/item/{menuItemId}")
    public ItemReviewsResponse getReviewsByItem(@PathVariable UUID menuItemId) {
        return reviewsService.getReviewsByItem(menuItemId);
    }

    /**
     * GET /api/reviews/order/:orderId — CUSTOMER only
     *
     * NestJS:
     *   @UseGuards(JwtAuthGuard, RolesGuard) @Roles(Role.CUSTOMER)
     *   @Get('order/:orderId') getReviewsByOrder(@Request() req, @Param('orderId') orderId)
     *
     * The service validates that the order belongs to the requesting customer.
     */
    @GetMapping("/order/{orderId}")
    @PreAuthorize("hasRole('CUSTOMER')")
    public List<Review> getReviewsByOrder(@AuthenticationPrincipal User user,
                                          @PathVariable UUID orderId) {
        return reviewsService.getReviewsByOrder(orderId, user.getId());
    }

    /**
     * GET /api/reviews/my — CUSTOMER only
     *
     * Returns a plain list of order UUIDs that the authenticated customer has
     * already reviewed. Response: ["uuid1", "uuid2", ...]
     *
     * Intentionally returns UUIDs (not full Review entities) to avoid
     * Hibernate lazy-loading serialisation errors (ByteBuddyInterceptor)
     * that occur when Jackson encounters unloaded LAZY proxies.
     * The Flutter app only needs the IDs — it uses them to hide "Leave Review".
     */
    @GetMapping("/my")
    @PreAuthorize("hasRole('CUSTOMER')")
    public List<UUID> getMyReviewedOrderIds(@AuthenticationPrincipal User user) {
        return reviewsService.getMyReviewedOrderIds(user.getId());
    }

    /**
     * GET /api/reviews — MANAGER only
     *
     * NestJS:
     *   @UseGuards(JwtAuthGuard, RolesGuard) @Roles(Role.MANAGER)
     *   @Get() getAllReviews()
     */
    @GetMapping
    @PreAuthorize("hasRole('MANAGER')")
    public List<Review> getAllReviews() {
        return reviewsService.getAllReviews();
    }
}
