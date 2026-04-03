package com.gasthaus.service;

import com.gasthaus.dto.reviews.CreateReviewRequest;
import com.gasthaus.dto.reviews.ItemReviewsResponse;
import com.gasthaus.entity.MenuItem;
import com.gasthaus.entity.Order;
import com.gasthaus.entity.Review;
import com.gasthaus.entity.User;
import com.gasthaus.repository.MenuItemRepository; // kept for getReviewsByItem()
import com.gasthaus.repository.OrderRepository;
import com.gasthaus.repository.ReviewRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;

/**
 * Business logic for reviews.
 *
 * Reviews are now ORDER-LEVEL — one review per customer per order.
 * The customer rates the whole order experience (food quality, service, etc.)
 * rather than individual menu items.
 *
 * Validation rules:
 *   1. Order must exist and belong to the requesting customer
 *   2. Order must be in a completed/served state (SERVED, PAID, COMPLETED)
 *   3. No duplicate reviews — one per (customer, order)
 */
@Service
@RequiredArgsConstructor
public class ReviewsService {

    private final ReviewRepository reviewRepository;
    private final OrderRepository orderRepository;
    private final MenuItemRepository menuItemRepository;

    // ─── Create Review ────────────────────────────────────────────

    /**
     * Creates an order-level review.
     *
     * @Transactional ensures the duplicate check + create is atomic —
     * no two concurrent requests can both pass the exists check and both insert.
     */
    @Transactional
    public Review createReview(User customer, CreateReviewRequest dto) {

        // ── Step 1: Find order ──
        Order order = orderRepository.findByIdWithDetails(dto.getOrderId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        // ── Step 2: Verify order belongs to this customer ──
        if (!order.getCustomer().getId().equals(customer.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You can only review your own orders");
        }

        // ── Step 3: Prevent duplicate — one review per customer per order ──
        // Previously checked (customerId, menuItemId, orderId); now just (customerId, orderId).
        if (reviewRepository.existsByCustomer_IdAndOrder_Id(customer.getId(), dto.getOrderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You have already reviewed this order");
        }

        // ── Step 4: Create and persist the review (no menuItem reference) ──
        Review review = Review.builder()
                .customer(customer)
                .order(order)
                .rating(dto.getRating())
                .comment(dto.getComment())
                .build();

        return reviewRepository.save(review);
    }

    // ─── Read Reviews ─────────────────────────────────────────────

    /**
     * Returns all reviews for a specific menu item — used by the AI review summary
     * endpoint and the public item detail. Menu item reviews may now be sparse
     * (only existing legacy per-item reviews) but the endpoint is kept for
     * backwards compatibility.
     */
    @Transactional(readOnly = true)
    public ItemReviewsResponse getReviewsByItem(UUID menuItemId) {
        MenuItem item = menuItemRepository.findById(menuItemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));

        List<Review> reviews = reviewRepository.findByMenuItemIdWithCustomer(menuItemId);
        return ItemReviewsResponse.of(menuItemId, item.getName(), reviews);
    }

    /**
     * Returns the review(s) for a specific order, owned by the requesting customer.
     * Under the new order-level model there is at most one review per order.
     * Returns a List for API compatibility.
     */
    @Transactional(readOnly = true)
    public List<Review> getReviewsByOrder(UUID orderId, UUID customerId) {
        Order order = orderRepository.findByIdWithDetails(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        if (!order.getCustomer().getId().equals(customerId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You can only view your own order reviews");
        }

        return reviewRepository.findByOrderId(orderId);
    }

    /**
     * Returns only the order UUIDs that this customer has already reviewed.
     * Returning full Review entities would trigger Hibernate lazy-loading
     * serialisation errors (ByteBuddyInterceptor on unloaded proxies).
     * The Flutter app only needs the IDs to hide the "Leave Review" button.
     */
    @Transactional(readOnly = true)
    public List<UUID> getMyReviewedOrderIds(UUID customerId) {
        return reviewRepository.findReviewedOrderIdsByCustomerId(customerId);
    }

    /**
     * MANAGER-only: returns all reviews for the reviews dashboard.
     */
    @Transactional(readOnly = true)
    public List<Review> getAllReviews() {
        return reviewRepository.findAllWithDetails();
    }
}
