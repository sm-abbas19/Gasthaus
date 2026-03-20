import {
  Controller, Post, Delete,
  Body, Param, UseGuards, Request,
} from '@nestjs/common';
import { AiService } from './ai.service';
import { RecommendDto } from './dto/recommend.dto';
import { InsightsDto } from './dto/insights.dto';
import { ReviewSummaryDto } from './dto/review-summary.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';

@Controller('ai')
@UseGuards(JwtAuthGuard)
export class AiController {
  constructor(private aiService: AiService) {}

  @Post('recommend')
  @Roles(Role.CUSTOMER)
  @UseGuards(RolesGuard)
  recommend(@Request() req, @Body() dto: RecommendDto) {
    return this.aiService.getRecommendation(
      req.user.id,
      dto.message,
      dto.menuItems,
    );
  }

  @Post('insights')
  @Roles(Role.MANAGER)
  @UseGuards(RolesGuard)
  insights(@Body() dto: InsightsDto) {
    return this.aiService.getInsights(dto);
  }

  @Post('review-summary')
  reviewSummary(@Body() dto: ReviewSummaryDto) {
    return this.aiService.getReviewSummary(dto.menuItemName, dto.reviews);
  }

  @Delete('session')
  @Roles(Role.CUSTOMER)
  @UseGuards(RolesGuard)
  clearSession(@Request() req) {
    return this.aiService.clearSession(req.user.id);
  }
}