import { IsString, IsNumber, IsOptional, IsBoolean, IsUUID } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateItemDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  price?: number;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}