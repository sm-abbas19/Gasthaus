import { IsInt, IsNumber, IsArray, IsOptional, IsString } from 'class-validator';

export class InsightsDto {
  @IsInt()
  totalOrders: number;

  @IsNumber()
  totalRevenue: number;

  @IsArray()
  topItems: any[];

  @IsOptional()
  @IsString()
  busiestHour?: string;

  @IsOptional()
  @IsArray()
  complaints?: string[];
}