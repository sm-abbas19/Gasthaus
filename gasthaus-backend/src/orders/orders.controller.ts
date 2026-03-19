import {
  Controller, Get, Post, Patch,
  Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private ordersService: OrdersService) {}

  @Post()
  @Roles(Role.CUSTOMER)
  @UseGuards(RolesGuard)
  createOrder(@Request() req, @Body() dto: CreateOrderDto) {
    return this.ordersService.createOrder(req.user.id, dto);
  }

  @Get()
  @Roles(Role.WAITER, Role.KITCHEN, Role.MANAGER)
  @UseGuards(RolesGuard)
  getAllOrders() {
    return this.ordersService.getAllOrders();
  }

  @Get('my')
  getMyOrders(@Request() req) {
    return this.ordersService.getMyOrders(req.user.id);
  }

  @Get(':id')
  getOrderById(@Param('id') id: string) {
    return this.ordersService.getOrderById(id);
  }

  @Patch(':id/status')
  @Roles(Role.WAITER, Role.KITCHEN, Role.MANAGER)
  @UseGuards(RolesGuard)
  updateStatus(@Param('id') id: string, @Body() dto: UpdateOrderStatusDto) {
    return this.ordersService.updateStatus(id, dto);
  }
}