import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrdersGateway } from './orders.gateway';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { OrderStatus } from '@prisma/client';

const STATUS_FLOW: Record<OrderStatus, OrderStatus | null> = {
  [OrderStatus.PENDING]:   OrderStatus.CONFIRMED,
  [OrderStatus.CONFIRMED]: OrderStatus.PREPARING,
  [OrderStatus.PREPARING]: OrderStatus.READY,
  [OrderStatus.READY]:     OrderStatus.SERVED,
  [OrderStatus.SERVED]:    OrderStatus.COMPLETED,
  [OrderStatus.COMPLETED]: null,
  [OrderStatus.CANCELLED]: null,
};

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private gateway: OrdersGateway,
  ) {}

  // ─── Create Order ─────────────────────────────

  async createOrder(customerId: string, dto: CreateOrderDto) {
    // 1. Verify table exists
    const table = await this.prisma.restaurantTable.findUnique({
      where: { id: dto.tableId },
    });
    if (!table) throw new NotFoundException('Table not found');

    // 2. Fetch all menu items in one query
    const menuItemIds = dto.items.map((item) => item.menuItemId);
    const uniqueMenuItemIds = [...new Set(menuItemIds)];
    const menuItems = await this.prisma.menuItem.findMany({
      where: { id: { in: uniqueMenuItemIds }, isAvailable: true },
    });

    // 3. Validate all items exist and are available
    const foundIds = new Set(menuItems.map((item) => item.id));
    const missingIds = uniqueMenuItemIds.filter((id) => !foundIds.has(id));
    if (missingIds.length > 0) {
      throw new BadRequestException(
        `One or more items are unavailable or do not exist: ${missingIds.join(', ')}`,
      );
    }

    const menuItemsById = new Map(menuItems.map((item) => [item.id, item]));
    const getMenuItemOrThrow = (menuItemId: string) => {
      const menuItem = menuItemsById.get(menuItemId);
      if (!menuItem) {
        throw new BadRequestException(
          `Menu item ${menuItemId} is unavailable or does not exist`,
        );
      }
      return menuItem;
    };

    // 4. Calculate total
    const total = dto.items.reduce((sum, orderItem) => {
      const menuItem = getMenuItemOrThrow(orderItem.menuItemId);
      return sum + menuItem.price * orderItem.quantity;
    }, 0);

    // 5. Create order with items AND mark table occupied in one transaction
const order = await this.prisma.$transaction(async (tx) => {
  const createdOrder = await tx.order.create({
    data: {
      customerId,
      tableId: dto.tableId,
      totalAmount: total,
      items: {
        create: dto.items.map((orderItem) => {
          const menuItem = getMenuItemOrThrow(orderItem.menuItemId);
          return {
            menuItemId: orderItem.menuItemId,
            quantity: orderItem.quantity,
            unitPrice: menuItem.price,
            notes: orderItem.notes,
          };
        }),
      },
    },
    include: {
      items: { include: { menuItem: true } },
      customer: { select: { id: true, name: true, email: true } },
      table: true,
    },
  });

  await tx.restaurantTable.update({
    where: { id: dto.tableId },
    data: { isOccupied: true },
  });

  return createdOrder;
});

// 6. Emit WebSocket event to staff dashboard
this.gateway.emitNewOrder(order);

return order;

    // 7. Emit WebSocket event to staff dashboard
    this.gateway.emitNewOrder(order);

    return order;
  }

  // ─── Get Orders ───────────────────────────────

  async getAllOrders() {
    return this.prisma.order.findMany({
      where: {
        status: {
          notIn: [OrderStatus.COMPLETED, OrderStatus.CANCELLED],
        },
      },
      include: {
        items: { include: { menuItem: true } },
        customer: { select: { id: true, name: true } },
        table: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getOrderById(id: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: {
        items: { include: { menuItem: true } },
        customer: { select: { id: true, name: true, email: true } },
        table: true,
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  async getMyOrders(customerId: string) {
    return this.prisma.order.findMany({
      where: { customerId },
      include: {
        items: { include: { menuItem: true } },
        table: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ─── Update Status ────────────────────────────

  async updateStatus(id: string, dto: UpdateOrderStatusDto) {
    const order = await this.getOrderById(id);

    // Validate status transition
    const allowedNext = STATUS_FLOW[order.status];
    if (dto.status !== OrderStatus.CANCELLED && dto.status !== allowedNext) {
      throw new BadRequestException(
        `Cannot transition from ${order.status} to ${dto.status}. Expected ${allowedNext}`,
      );
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: { status: dto.status },
      include: {
        items: { include: { menuItem: true } },
        customer: { select: { id: true, name: true } },
        table: true,
      },
    });

    // Free up table when order completes or cancels
    if (
      dto.status === OrderStatus.COMPLETED ||
      dto.status === OrderStatus.CANCELLED
    ) {
      await this.prisma.restaurantTable.update({
        where: { id: order.tableId },
        data: { isOccupied: false },
      });
    }

    // Emit appropriate WebSocket event
    if (dto.status === OrderStatus.READY) {
      this.gateway.emitOrderReady(updated);
    } else {
      this.gateway.emitOrderStatusUpdate(updated);
    }

    return updated;
  }
}