import { IsUUID, IsInt, IsOptional, IsString, Min, Max } from 'class-validator';

export class CreateReviewDto {
  @IsUUID()
  menuItemId: string;

  @IsUUID()
  orderId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @IsString()
  comment?: string;
}