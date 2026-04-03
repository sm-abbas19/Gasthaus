package com.gasthaus.service;

import com.gasthaus.dto.reviews.CreateReviewRequest;
import com.gasthaus.dto.reviews.ItemReviewsResponse;
import com.gasthaus.entity.MenuItem;
import com.gasthaus.entity.Order;
import com.gasthaus.entity.Review;
import com.gasthaus.entity.User;
import com.gasthaus.repository.MenuItemRepository;
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
 * NestJS equivalent: ReviewsService in src/reviews/reviews.service.ts
 *
 * Key validations (mirrored from NestJS):
 *   1. Order must exist and belong to the requesting customer
 *   2. The reviewed menu item must have been part of that order
 *   3. No duplicate reviews (same customer + item + order combination)
 */
@Service
@RequiredArgsConstructor
public class ReviewsService {

    private final ReviewRepository reviewRepository;
    private final OrderRepository orderRepository;
    private final MenuItemRepository menuItemRepository;

    // ─── Create Review ────────────────────────────────────────────

    /**
     * NestJS:
     *   async createReview(customerId, dto) {
     *     const order = await prisma.order.findUnique({ where: { id }, include: { items: true } });
     *     if (!order) throw NotFoundException
     *     if (order.customerId !== customerId) throw BadRequest
     *     const itemInOrder = order.items.some(i => i.menuItemId === dto.menuItemId);
     *     if (!itemInOrder) throw BadRequest
     *     const existing = await prisma.review.findFirst({ where: { customerId, menuItemId, orderId } });
     *     if (existing) throw BadRequest
     *     return prisma.review.create({ data: {...}, include: { customer, menuItem } });
     *   }
     *
     * @Transactional ensures the existence check + create is atomic —
     * no duplicate reviews can slip through concurrent requests.
     */
    @Transactional
    public Review createReview(User customer, CreateReviewRequest dto) {

        // ── Step 1: Find order with items ──
        // findByIdWithDetails JOIN FETCHes items, so order.getItems() is loaded.
        Order order = orderRepository.findByIdWithDetails(dto.getOrderId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        // ── Step 2: Verify order belongs to this customer ──
        // NestJS: if (order.customerId !== customerId) throw BadRequestException
        if (!order.getCustomer().getId().equals(customer.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You can only review your own orders");
        }

        // ── Step 3: Verify the menu item was part of this order ──
        // NestJS: order.items.some(item => item.menuItemId === dto.menuItemId)
        boolean itemInOrder = order.getItems().stream()
                .anyMatch(item -> item.getMenuItem().getId().equals(dto.getMenuItemId()));

        if (!itemInOrder) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "This item was not part of your order");
        }

        // ── Step 4: Prevent duplicate reviews ──
        // NestJS: prisma.review.findFirst({ where: { customerId, menuItemId, orderId } })
        // We use the existsBy method which is more efficient than fetching the full entity.
        if (reviewRepository.existsByCustomer_IdAndMenuItem_IdAndOrder_Id(
                customer.getId(), dto.getMenuItemId(), dto.getOrderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You have already reviewed this item");
        }

        // ── Step 5: Fetch the MenuItem entity for the review relation ──
        MenuItem menuItem = menuItemRepository.findById(dto.getMenuItemId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));

        // ── Step 6: Create and persist the review ──
        Review review = Review.builder()
                .customer(customer)
                .menuItem(menuItem)
                .order(order)
                .rating(dto.getRating())
                .comment(dto.getComment())
                .build();

        return reviewRepository.save(review);
    }

    // ─── Read Reviews ─────────────────────────────────────────────

    /**
     * NestJS:
     *   async getReviewsByItem(menuItemId) {
     *     const item = await prisma.menuItem.findUnique({ where: { id: menuItemId } });
     *     if (!item) throw NotFoundException
     *     const reviews = await prisma.review.findMany({
     *       where: { menuItemId }, include: { customer: { select: { id, name } } },
     *       orderBy: { createdAt: 'desc' }
     *     });
     *     const avgRating = reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;
     *     return { menuItemId, menuItemName, averageRating, totalReviews, reviews };
     *   }
     *
     * ItemReviewsResponse.of() replicates the NestJS average rating calculation.
     */
    @Transactional(readOnly = true)
    public ItemReviewsResponse getReviewsByItem(UUID menuItemId) {
        MenuItem item = menuItemRepository.findById(menuItemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));

        List<Review> reviews = reviewRepository.findByMenuItemIdWithCustomer(menuItemId);
        return ItemReviewsResponse.of(menuItemId, item.getName(), reviews);
    }

    /**
     * NestJS:
     *   async getReviewsByOrder(orderId, customerId) {
     *     const order = await prisma.order.findUnique({ where: { id: orderId } });
     *     if (!order) throw NotFoundException
     *     if (order.customerId !== customerId) throw BadRequest
     *     return prisma.review.findMany({
     *       where: { orderId }, include: { menuItem: { select: { id, name } } },
     *       orderBy: { createdAt: 'desc' }
     *     });
     *   }
     */
    @Transactional(readOnly = true)
    public List<Review> getReviewsByOrder(UUID orderId, UUID customerId) {
        Order order = orderRepository.findByIdWithDetails(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        if (!order.getCustomer().getId().equals(customerId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You can only view your own order reviews");
        }

        return reviewRepository.findByOrderIdWithMenuItem(orderId);
    }

    /**
     * NestJS: prisma.review.findMany({ include: { customer, menuItem }, orderBy: { createdAt: 'desc' } })
     * MANAGER-only endpoint — returns all reviews for the reviews dashboard.
     */
    @Transactional(readOnly = true)
    public List<Review> getAllReviews() {
        return reviewRepository.findAllWithDetails();
    }
}
