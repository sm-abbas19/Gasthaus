import { Injectable, HttpException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AiService {
  private fastApiUrl: string;

  constructor(
    private httpService: HttpService,
    private config: ConfigService,
  ) {
    this.fastApiUrl = this.config.get<string>('FASTAPI_URL') || 'http://localhost:8000';
  }

  async getRecommendation(userId: string, message: string, menuItems: any[]) {
    try {
      const { data } = await firstValueFrom(
        this.httpService.post(`${this.fastApiUrl}/ai/recommend`, {
          userId,
          message,
          menuItems,
        }),
      );
      return data;
    } catch (error) {
      throw new HttpException(
        error.response?.data?.detail || 'AI service unavailable',
        error.response?.status || 503,
      );
    }
  }

  async getInsights(insightsData: any) {
    try {
      const { data } = await firstValueFrom(
        this.httpService.post(`${this.fastApiUrl}/ai/insights`, insightsData),
      );
      return data;
    } catch (error) {
      throw new HttpException(
        error.response?.data?.detail || 'AI service unavailable',
        error.response?.status || 503,
      );
    }
  }

  async getReviewSummary(menuItemName: string, reviews: any[]) {
    try {
      const { data } = await firstValueFrom(
        this.httpService.post(`${this.fastApiUrl}/ai/review-summary`, {
          menuItemName,
          reviews,
        }),
      );
      return data;
    } catch (error) {
      throw new HttpException(
        error.response?.data?.detail || 'AI service unavailable',
        error.response?.status || 503,
      );
    }
  }

  async clearSession(userId: string) {
    try {
      const { data } = await firstValueFrom(
        this.httpService.delete(`${this.fastApiUrl}/ai/session/${userId}`),
      );
      return data;
    } catch (error) {
      throw new HttpException(
        error.response?.data?.detail || 'AI service unavailable',
        error.response?.status || 503,
      );
    }
  }
}