package com.gasthaus.repository;

import com.gasthaus.entity.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * Repository for Review.
 *
 * NestJS equivalent: prisma.review.findMany / findFirst / create
 *
 * All review relationships are @ManyToOne (customer, menuItem, order),
 * so Spring Data resolves nested properties: MenuItem_Id → menuItem.id, etc.
 */
@Repository
public interface ReviewRepository extends JpaRepository<Review, UUID> {

    /**
     * Prisma:
     *   prisma.review.findFirst({
     *     where: { customerId, menuItemId, orderId }
     *   })
     *   → used to prevent duplicate reviews
     *
     * Returns boolean — more efficient than fetching the whole entity
     * when we only need to know if a review already exists.
     *
     * Spring Data resolves the property paths:
     *   Customer_Id → customer.id
     *   MenuItem_Id → menuItem.id
     *   Order_Id    → order.id
     */
    boolean existsByCustomer_IdAndMenuItem_IdAndOrder_Id(
            UUID customerId, UUID menuItemId, UUID orderId);

    /**
     * Prisma:
     *   prisma.review.findMany({
     *     where: { menuItemId },
     *     include: { customer: { select: { id, name } } },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * Used in ReviewsService.getReviewsByItem() for the public item review page.
     * JOIN FETCH customer so the service can include customer name in the response.
     */
    @Query("""
            SELECT r FROM Review r
            JOIN FETCH r.customer
            WHERE r.menuItem.id = :menuItemId
            ORDER BY r.createdAt DESC
            """)
    List<Review> findByMenuItemIdWithCustomer(@Param("menuItemId") UUID menuItemId);

    /**
     * Prisma:
     *   prisma.review.findMany({
     *     where: { orderId },
     *     include: { menuItem: { select: { id, name } } },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * Used in ReviewsService.getReviewsByOrder() for customers viewing their reviews.
     */
    @Query("""
            SELECT r FROM Review r
            JOIN FETCH r.menuItem
            WHERE r.order.id = :orderId
            ORDER BY r.createdAt DESC
            """)
    List<Review> findByOrderIdWithMenuItem(@Param("orderId") UUID orderId);

    /**
     * Prisma:
     *   prisma.review.findMany({
     *     include: { customer: {...}, menuItem: {...} },
     *     orderBy: { createdAt: 'desc' }
     *   })
     *
     * Used in ReviewsService.getAllReviews() for the manager reviews page.
     * Eagerly fetches both customer and menuItem to avoid N+1 on the full list.
     */
    @Query("""
            SELECT r FROM Review r
            JOIN FETCH r.customer
            JOIN FETCH r.menuItem
            ORDER BY r.createdAt DESC
            """)
    List<Review> findAllWithDetails();
}
