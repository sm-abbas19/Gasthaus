import {
  Controller, Get, Post, Patch, Delete,
  Param, Body, UseGuards, UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { MenuService } from './menu.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';

@Controller('menu')
export class MenuController {
  constructor(private menuService: MenuService) {}

  // ─── Categories ───────────────────────────────

  @Get('categories')
  getCategories() {
    return this.menuService.getCategories();
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Post('categories')
  createCategory(@Body() dto: CreateCategoryDto) {
    return this.menuService.createCategory(dto);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Delete('categories/:id')
  deleteCategory(@Param('id') id: string) {
    return this.menuService.deleteCategory(id);
  }

  // ─── Items ────────────────────────────────────

  @Get('items')
  getItems() {
    return this.menuService.getItems();
  }

  @Get('items/:id')
  getItemById(@Param('id') id: string) {
    return this.menuService.getItemById(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Post('items')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  createItem(
    @Body() dto: CreateItemDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.menuService.createItem(dto, image);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Patch('items/:id')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  updateItem(
    @Param('id') id: string,
    @Body() dto: UpdateItemDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.menuService.updateItem(id, dto, image);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Delete('items/:id')
  deleteItem(@Param('id') id: string) {
    return this.menuService.deleteItem(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.MANAGER)
  @Patch('items/:id/toggle')
  toggleAvailability(@Param('id') id: string) {
    return this.menuService.toggleAvailability(id);
  }
}