import { IsString, IsArray } from 'class-validator';

export class ReviewSummaryDto {
  @IsString()
  menuItemName: string;

  @IsArray()
  reviews: any[];
}