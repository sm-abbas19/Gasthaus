package com.gasthaus.repository;

import com.gasthaus.entity.RestaurantTable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for RestaurantTable.
 *
 * NestJS equivalent: prisma.restaurantTable.findMany / findUnique / create / update / delete
 *
 * Note on deletion: NestJS's TablesService.deleteTable() catches Prisma error P2003
 * (foreign key constraint violation) and converts it to a 400 BadRequest.
 * In Spring, the equivalent is DataIntegrityViolationException thrown by JPA.
 * The service layer will catch that and rethrow as ResponseStatusException.
 */
@Repository
public interface RestaurantTableRepository extends JpaRepository<RestaurantTable, UUID> {

    /**
     * Prisma: prisma.restaurantTable.findUnique({ where: { tableNumber } })
     *
     * Used in:
     *   - TablesService.getTableByNumber() — public QR scan endpoint
     *   - TablesService.createTable()      — duplicate check before insert
     *
     * Derived query: SELECT t FROM RestaurantTable t WHERE t.tableNumber = ?1
     */
    Optional<RestaurantTable> findByTableNumber(int tableNumber);

    /**
     * Prisma: prisma.restaurantTable.findMany({ orderBy: { tableNumber: 'asc' } })
     * Used in TablesService.getAllTables() and getTableStats().
     *
     * Derived query: SELECT t FROM RestaurantTable t ORDER BY t.tableNumber ASC
     */
    List<RestaurantTable> findAllByOrderByTableNumberAsc();
}
