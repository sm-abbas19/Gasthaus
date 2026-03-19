import {
  Controller, Get, Post,
  Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { ReviewsService } from './reviews.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';

@Controller('reviews')
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CUSTOMER)
  @Post()
  createReview(@Request() req, @Body() dto: CreateReviewDto) {
    return this.reviewsService.createReview(req.user.id, dto);
  }

  @Get('item/:menuItemId')
  getReviewsByItem(@Param('menuItemId') menuItemId: string) {
    return this.reviewsService.getReviewsByItem(menuItemId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CUSTOMER)
  @Get('order/:orderId')
  getReviewsByOrder(@Request() req, @Param('orderId') orderId: string) {
    return this.reviewsService.getReviewsByOrder(orderId, req.user.id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Get()
  getAllReviews() {
    return this.reviewsService.getAllReviews();
  }
}