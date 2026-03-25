import {
  Controller, Get, Post, Delete, Patch,
  Param, Body, UseGuards, Request, HttpCode, HttpStatus,
} from '@nestjs/common';
import { TablesService } from './tables.service';
import { CreateTableDto } from './dto/create-table.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';

@Controller('tables')
export class TablesController {
  constructor(private tablesService: TablesService) {}

  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER, Role.WAITER)
  getAllTables() {
    return this.tablesService.getAllTables();
  }

  @Get('stats')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER, Role.WAITER)
  getTableStats() {
    return this.tablesService.getTableStats();
  }

  @Get('number/:tableNumber')
  getTableByNumber(@Param('tableNumber') tableNumber: string) {
    return this.tablesService.getTableByNumber(Number(tableNumber));
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER, Role.WAITER)
  getTableById(@Param('id') id: string) {
    return this.tablesService.getTableById(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  createTable(@Request() req, @Body() dto: CreateTableDto) {
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    return this.tablesService.createTable(dto, baseUrl);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  deleteTable(@Param('id') id: string) {
    return this.tablesService.deleteTable(id);
  }

  @Patch(':id/toggle')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER, Role.WAITER)
  toggleOccupied(@Param('id') id: string) {
    return this.tablesService.toggleOccupied(id);
  }
}