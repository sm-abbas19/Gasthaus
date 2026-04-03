package com.gasthaus.dto.reviews;

import com.gasthaus.entity.Review;

import java.util.List;
import java.util.UUID;

/**
 * Response shape for GET /reviews/item/:menuItemId.
 *
 * NestJS equivalent: the plain object returned by ReviewsService.getReviewsByItem():
 *   { menuItemId, menuItemName, averageRating, totalReviews, reviews }
 *
 * NestJS returns this as a plain object literal — no class needed.
 * In Java we use a record to produce the same JSON structure.
 *
 * averageRating is rounded to 1 decimal place:
 *   NestJS: Math.round(avgRating * 10) / 10
 *   Java:   Math.round(avg * 10.0) / 10.0
 */
public record ItemReviewsResponse(
        UUID menuItemId,
        String menuItemName,
        double averageRating,
        int totalReviews,
        List<Review> reviews
) {
    public static ItemReviewsResponse of(UUID menuItemId, String menuItemName, List<Review> reviews) {
        double avg = reviews.isEmpty() ? 0.0
                : reviews.stream().mapToInt(Review::getRating).average().orElse(0.0);
        double rounded = Math.round(avg * 10.0) / 10.0;
        return new ItemReviewsResponse(menuItemId, menuItemName, rounded, reviews.size(), reviews);
    }
}
