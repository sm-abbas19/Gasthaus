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
 * Reviews are now order-level (one per customer per order), so the duplicate
 * check method is now existsByCustomer_IdAndOrder_Id instead of the old
 * three-way (customer, menuItem, order) check.
 *
 * menuItem is nullable on Review, so all JPQL queries that join on menuItem
 * use LEFT JOIN FETCH to avoid excluding reviews that have no menuItem.
 */
@Repository
public interface ReviewRepository extends JpaRepository<Review, UUID> {

    /**
     * Duplicate check: has this customer already reviewed this order?
     * One review per (customer, order) — enforced here AND via @UniqueConstraint.
     *
     * Spring Data resolves:
     *   Customer_Id → customer.id
     *   Order_Id    → order.id
     */
    boolean existsByCustomer_IdAndOrder_Id(UUID customerId, UUID orderId);

    /**
     * Fetch reviews for a menu item with customer names eagerly loaded.
     * Used by getReviewsByItem() — legacy per-item reviews only.
     *
     * LEFT JOIN FETCH r.menuItem is not needed here since we're already
     * filtering by menuItemId, but we LEFT JOIN FETCH customer to avoid N+1.
     */
    @Query("""
            SELECT r FROM Review r
            JOIN FETCH r.customer
            WHERE r.menuItem.id = :menuItemId
            ORDER BY r.createdAt DESC
            """)
    List<Review> findByMenuItemIdWithCustomer(@Param("menuItemId") UUID menuItemId);

    /**
     * Fetch all reviews for an order.
     * Under the new order-level model this returns at most one result.
     * Returns List for API compatibility with getReviewsByOrder().
     */
    @Query("""
            SELECT r FROM Review r
            WHERE r.order.id = :orderId
            ORDER BY r.createdAt DESC
            """)
    List<Review> findByOrderId(@Param("orderId") UUID orderId);

    /**
     * MANAGER dashboard: fetch all reviews with customer eagerly loaded.
     * LEFT JOIN FETCH r.menuItem handles the nullable menuItem on order-level reviews —
     * without LEFT, reviews with no menuItem would be excluded from results.
     */
    @Query("""
            SELECT r FROM Review r
            JOIN FETCH r.customer
            LEFT JOIN FETCH r.menuItem
            ORDER BY r.createdAt DESC
            """)
    List<Review> findAllWithDetails();
}
