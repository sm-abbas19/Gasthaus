import { IsInt, IsPositive } from 'class-validator';

export class CreateTableDto {
  @IsInt()
  @IsPositive()
  tableNumber: number;
}