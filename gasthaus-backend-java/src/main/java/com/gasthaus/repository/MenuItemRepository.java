package com.gasthaus.repository;

import com.gasthaus.entity.MenuItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Repository for MenuItem.
 *
 * NestJS equivalent: prisma.menuItem.findMany / findUnique / create / update / delete
 *
 * Key query: when creating an order, NestJS fetches all requested items in one
 * query using findMany({ where: { id: { in: [...] }, isAvailable: true } }).
 * Spring Data translates this to findByIdInAndIsAvailableTrue().
 */
@Repository
public interface MenuItemRepository extends JpaRepository<MenuItem, UUID> {

    /**
     * Prisma: prisma.menuItem.findMany({ orderBy: { createdAt: 'desc' } })
     * Used in MenuService.getItems() for the admin item list.
     *
     * Derived query: WHERE 1=1 ORDER BY created_at DESC
     * The "AllBy" is optional — findAllByOrderByCreatedAtDesc works the same.
     */
    List<MenuItem> findAllByOrderByCreatedAtDesc();

    /**
     * Prisma:
     *   prisma.menuItem.findMany({
     *     where: { id: { in: menuItemIds }, isAvailable: true }
     *   })
     *
     * Used in OrdersService.createOrder() to batch-validate all requested items.
     * "In" maps to SQL IN (?), "AndIsAvailableTrue" maps to AND is_available = TRUE.
     *
     * Accepts Collection<UUID> (covers List, Set, etc.) — Spring Data handles the
     * SQL IN clause automatically regardless of collection size.
     */
    List<MenuItem> findByIdInAndIsAvailableTrue(Collection<UUID> ids);

    /**
     * Prisma:
     *   prisma.menuItem.findUnique({ where: { id }, include: { category: true, reviews: {...} } })
     *
     * JOIN FETCH to avoid N+1 when loading a single item with its category.
     * Reviews are loaded separately in the service (they need customer info too).
     */
    @Query("SELECT i FROM MenuItem i JOIN FETCH i.category WHERE i.id = :id")
    java.util.Optional<MenuItem> findByIdWithCategory(UUID id);
}
