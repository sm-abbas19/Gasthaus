import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  async createReview(customerId: string, dto: CreateReviewDto) {
    // 1. Verify order exists and belongs to this customer
    const order = await this.prisma.order.findUnique({
      where: { id: dto.orderId },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.customerId !== customerId) {
      throw new BadRequestException('You can only review your own orders');
    }

    // 2. Verify the menu item was actually part of this order
    const itemInOrder = order.items.some(
      (item) => item.menuItemId === dto.menuItemId,
    );
    if (!itemInOrder) {
      throw new BadRequestException('This item was not part of your order');
    }

    // 3. Prevent duplicate reviews
    const existing = await this.prisma.review.findFirst({
      where: {
        customerId,
        menuItemId: dto.menuItemId,
        orderId: dto.orderId,
      },
    });
    if (existing) {
      throw new BadRequestException('You have already reviewed this item');
    }

    // 4. Create the review
    return this.prisma.review.create({
      data: {
        customerId,
        menuItemId: dto.menuItemId,
        orderId: dto.orderId,
        rating: dto.rating,
        comment: dto.comment,
      },
      include: {
        customer: { select: { id: true, name: true } },
        menuItem: { select: { id: true, name: true } },
      },
    });
  }

  async getReviewsByItem(menuItemId: string) {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: menuItemId },
    });
    if (!item) throw new NotFoundException('Menu item not found');

    const reviews = await this.prisma.review.findMany({
      where: { menuItemId },
      include: {
        customer: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Calculate average rating
    const avgRating =
      reviews.length > 0
        ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length
        : 0;

    return {
      menuItemId,
      menuItemName: item.name,
      averageRating: Math.round(avgRating * 10) / 10,
      totalReviews: reviews.length,
      reviews,
    };
  }

  async getReviewsByOrder(orderId: string, customerId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.customerId !== customerId) {
      throw new BadRequestException('You can only view your own order reviews');
    }

    return this.prisma.review.findMany({
      where: { orderId },
      include: {
        menuItem: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllReviews() {
    return this.prisma.review.findMany({
      include: {
        customer: { select: { id: true, name: true } },
        menuItem: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}