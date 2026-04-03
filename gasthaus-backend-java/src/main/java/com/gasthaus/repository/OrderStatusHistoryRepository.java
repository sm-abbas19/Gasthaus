package com.gasthaus.repository;

import com.gasthaus.entity.OrderStatusHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * Repository for OrderStatusHistory.
 *
 * We only ever INSERT history entries (never update or delete them), so
 * the default save() from JpaRepository is all we need here.
 *
 * NestJS equivalent: prisma.orderStatusHistory.create({ data: { orderId, status } })
 */
@Repository
public interface OrderStatusHistoryRepository extends JpaRepository<OrderStatusHistory, UUID> {
}
