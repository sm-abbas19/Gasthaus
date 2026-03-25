package com.gasthaus.repository;

import com.gasthaus.entity.MenuCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * Repository for MenuCategory.
 *
 * NestJS equivalent: prisma.menuCategory.findMany / findUnique / create / delete
 *
 * Key challenge: the NestJS getCategories() call does:
 *   prisma.menuCategory.findMany({
 *     include: { items: { where: { isAvailable: true }, orderBy: { name: 'asc' } } },
 *     orderBy: { name: 'asc' }
 *   })
 *
 * With JPA LAZY loading (all collections are lazy), calling findAll() and then
 * accessing category.getItems() in a loop causes N+1 queries — one per category.
 *
 * Solution: Use a single @Query with JOIN FETCH to load categories AND their
 * available items in one SQL statement. This is the JPA equivalent of Prisma's
 * nested "include".
 *
 * Note: JOIN FETCH with a WHERE on the child requires LEFT JOIN FETCH so that
 * categories with zero available items are still returned.
 */
@Repository
public interface MenuCategoryRepository extends JpaRepository<MenuCategory, UUID> {

    /**
     * Prisma:
     *   prisma.menuCategory.findMany({
     *     include: { items: { where: { isAvailable: true }, orderBy: { name: 'asc' } } },
     *     orderBy: { name: 'asc' }
     *   })
     *
     * JPQL breakdown:
     *   SELECT DISTINCT c  — DISTINCT prevents duplicate Category rows when a
     *                        category has multiple items (JPA flattens the join)
     *   FROM MenuCategory c
     *   LEFT JOIN FETCH c.items i  — LEFT so categories with no available items
     *                                still appear; FETCH loads items in one query
     *   WHERE i.isAvailable = true OR i IS NULL
     *                             — only include available items, but keep
     *                                categories even if they have none
     *   ORDER BY c.name ASC, i.name ASC
     *
     * The "DISTINCT" in JPQL removes the duplicated parent rows from the join
     * result — it does NOT add DISTINCT to the SQL (Hibernate handles this).
     */
    @Query("""
            SELECT DISTINCT c FROM MenuCategory c
            LEFT JOIN FETCH c.items i
            WHERE i.isAvailable = true OR i IS NULL
            ORDER BY c.name ASC
            """)
    List<MenuCategory> findAllWithAvailableItemsOrderedByName();

    /**
     * Prisma: prisma.menuCategory.findMany({ orderBy: { name: 'asc' } })
     * Used for admin category listings where items aren't needed in the same call.
     *
     * Derived query: "findAll" + "By" + "OrderBy" + "Name" + "Asc"
     */
    List<MenuCategory> findAllByOrderByNameAsc();
}
