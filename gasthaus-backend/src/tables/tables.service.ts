import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTableDto } from './dto/create-table.dto';
import * as QRCode from 'qrcode';

@Injectable()
export class TablesService {
  constructor(private prisma: PrismaService) {}

  async getAllTables() {
    return this.prisma.restaurantTable.findMany({
      orderBy: { tableNumber: 'asc' },
      include: {
        orders: {
          where: {
            status: {
              notIn: ['COMPLETED', 'CANCELLED'],
            },
          },
          include: {
            items: { include: { menuItem: true } },
            customer: { select: { id: true, name: true } },
          },
        },
      },
    });
  }

  async getTableById(id: string) {
    const table = await this.prisma.restaurantTable.findUnique({
      where: { id },
      include: {
        orders: {
          where: {
            status: {
              notIn: ['COMPLETED', 'CANCELLED'],
            },
          },
          include: {
            items: { include: { menuItem: true } },
            customer: { select: { id: true, name: true } },
          },
        },
      },
    });
    if (!table) throw new NotFoundException('Table not found');
    return table;
  }

  async getTableByNumber(tableNumber: number) {
    const table = await this.prisma.restaurantTable.findUnique({
      where: { tableNumber },
    });
    if (!table) throw new NotFoundException('Table not found');
    return table;
  }

  async createTable(dto: CreateTableDto, baseUrl: string) {
    // Check if table number already exists
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { tableNumber: dto.tableNumber },
    });
    if (existing) {
      throw new ConflictException(
        `Table ${dto.tableNumber} already exists`,
      );
    }

    // Generate QR code data URL
    const qrData = `${baseUrl}/table/${dto.tableNumber}`;
    const qrCode = await QRCode.toDataURL(qrData);

    return this.prisma.restaurantTable.create({
      data: {
        tableNumber: dto.tableNumber,
        qrCode,
      },
    });
  }

  async deleteTable(id: string) {
  await this.findTableOrFail(id);
  try {
    return await this.prisma.restaurantTable.delete({ where: { id } });
  } catch (error) {
    if (error.code === 'P2003') {
      throw new BadRequestException(
        'Cannot delete table with existing orders. Complete or cancel all orders first.',
      );
    }
    throw error;
  }
}

  async toggleOccupied(id: string) {
    const table = await this.findTableOrFail(id);
    return this.prisma.restaurantTable.update({
      where: { id },
      data: { isOccupied: !table.isOccupied },
    });
  }

  async getTableStats() {
    const tables = await this.prisma.restaurantTable.findMany();
    const total = tables.length;
    const occupied = tables.filter((t) => t.isOccupied).length;
    const available = total - occupied;

    return { total, occupied, available };
  }

  private async findTableOrFail(id: string) {
    const table = await this.prisma.restaurantTable.findUnique({
      where: { id },
    });
    if (!table) throw new NotFoundException('Table not found');
    return table;
  }
}