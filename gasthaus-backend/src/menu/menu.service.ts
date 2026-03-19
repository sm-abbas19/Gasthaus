import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { v2 as cloudinary } from 'cloudinary';

@Injectable()
export class MenuService {
  constructor(private prisma: PrismaService) {
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });
  }

  // ─── Categories ───────────────────────────────

  async getCategories() {
    return this.prisma.menuCategory.findMany({
      include: {
        items: {
          where: { isAvailable: true },
          orderBy: { name: 'asc' },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async createCategory(dto: CreateCategoryDto) {
    return this.prisma.menuCategory.create({
      data: dto,
    });
  }

  async deleteCategory(id: string) {
    await this.findCategoryOrFail(id);
    return this.prisma.menuCategory.delete({ where: { id } });
  }

  // ─── Items ────────────────────────────────────

  async getItems() {
    return this.prisma.menuItem.findMany({
      include: { category: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getItemById(id: string) {
    const item = await this.prisma.menuItem.findUnique({
      where: { id },
      include: {
        category: true,
        reviews: {
          include: {
            customer: {
              select: { id: true, name: true },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!item) throw new NotFoundException('Menu item not found');
    return item;
  }

  async createItem(dto: CreateItemDto, imageFile?: Express.Multer.File) {
    await this.findCategoryOrFail(dto.categoryId);

    let imageUrl: string | undefined;
    if (imageFile) {
      imageUrl = await this.uploadImage(imageFile);
    }

    return this.prisma.menuItem.create({
      data: { ...dto, imageUrl },
      include: { category: true },
    });
  }

  async updateItem(id: string, dto: UpdateItemDto, imageFile?: Express.Multer.File) {
    await this.findItemOrFail(id);

    if (dto.categoryId) {
      await this.findCategoryOrFail(dto.categoryId);
    }

    let imageUrl: string | undefined;
    if (imageFile) {
      imageUrl = await this.uploadImage(imageFile);
    }

    return this.prisma.menuItem.update({
      where: { id },
      data: { ...dto, ...(imageUrl && { imageUrl }) },
      include: { category: true },
    });
  }

  async deleteItem(id: string) {
    await this.findItemOrFail(id);
    return this.prisma.menuItem.delete({ where: { id } });
  }

  async toggleAvailability(id: string) {
    const item = await this.findItemOrFail(id);
    return this.prisma.menuItem.update({
      where: { id },
      data: { isAvailable: !item.isAvailable },
      include: { category: true },
    });
  }

  // ─── Helpers ──────────────────────────────────

  private async findCategoryOrFail(id: string) {
    const category = await this.prisma.menuCategory.findUnique({ where: { id } });
    if (!category) throw new NotFoundException('Category not found');
    return category;
  }

  private async findItemOrFail(id: string) {
    const item = await this.prisma.menuItem.findUnique({ where: { id } });
    if (!item) throw new NotFoundException('Menu item not found');
    return item;
  }

  private async uploadImage(file: Express.Multer.File): Promise<string> {
  return new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream(
      { folder: 'gasthaus/menu' },
      (error, result) => {
        if (error) return reject(error);
        if (!result) return reject(new Error('Upload failed: No response from Cloudinary'));
        resolve(result.secure_url);
      },
    ).end(file.buffer);
  });
  }
}