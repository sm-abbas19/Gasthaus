import { IsString, IsArray } from 'class-validator';

export class RecommendDto {
  @IsString()
  message: string;

  @IsArray()
  menuItems: any[];
}