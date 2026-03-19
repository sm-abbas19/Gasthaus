import { IsString, IsNumber, IsOptional, IsBoolean, IsUUID } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateItemDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @Type(() => Number)
  @IsNumber()
  price: number;

  @IsUUID()
  categoryId: string;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}