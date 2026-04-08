import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  ForbiddenException,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import type { Request } from 'express';
import { Role } from '@prisma/client';

import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { VerifyPhotoDto } from './dto/verify-photo.dto';
import { Public } from '../auth/decorators/public.decorator';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';

type ReqWithUser = Request & { user: { sub: string; role: Role } };

@Controller('offers')
export class OffersController {
  constructor(private readonly offers: OffersService) {}

  private ensureRestaurant(req: ReqWithUser) {
    if (req.user.role !== Role.RESTAURANT) {
      throw new ForbiddenException('Only RESTAURANT can manage offers');
    }
  }

  /**
   * POST /offers/verify-photo
   * Send a base64 food photo for AI verification.
   */
  @Post('verify-photo')
  async verifyPhoto(@Req() req: ReqWithUser, @Body() dto: VerifyPhotoDto) {
    this.ensureRestaurant(req);
    // No EXIF/photo date logic, call the correct method
    return this.offers.verifyPhoto(dto.image);
  }

  /**
   * POST /offers
   * Create a new offer.
   */
  @Post()
  async create(@Req() req: ReqWithUser, @Body() dto: CreateOfferDto) {
    this.ensureRestaurant(req);
    return this.offers.createOffer(req.user.sub, dto);
  }

  /**
   * GET /offers/my
   * List all offers belonging to the current restaurant.
   */
  @Get('my')
  async getMyOffers(@Req() req: ReqWithUser) {
    this.ensureRestaurant(req);
    return this.offers.getMyOffers(req.user.sub);
  }

  /**
   * DELETE /offers/:id
   * Delete an offer.
   */
  @Delete(':id')
  async deleteOffer(@Req() req: ReqWithUser, @Param('id') id: string) {
    this.ensureRestaurant(req);
    return this.offers.deleteOffer(req.user.sub, id);
  }

  /**
   * PATCH /offers/:id/visibility
   * Toggle visibility between IDENTIFIED and ANONYMOUS.
   */
  @Patch(':id/visibility')
  async toggleVisibility(@Req() req: ReqWithUser, @Param('id') id: string) {
    this.ensureRestaurant(req);
    return this.offers.toggleVisibility(req.user.sub, id);
  }

  /**
   * PATCH /offers/:id/status
   * Toggle status between ACTIVE and PAUSED.
   */
  @Patch(':id/status')
  async toggleStatus(@Req() req: ReqWithUser, @Param('id') id: string) {
    this.ensureRestaurant(req);
    return this.offers.toggleStatus(req.user.sub, id);
  }

  @Public()
  @Get()
  async getAvailableOffers() {
    // No auth required (public route)
    return this.offers.getAvailableOffers();
  }

  @Post('upload-photo')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/offer-images',
        filename: (req, file, cb) => {
          // Generate a unique name for each file
          const uniqueName = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}${extname(file.originalname)}`;
          cb(null, uniqueName);
        },
      }),
      limits: { fileSize: 6 * 1024 * 1024 },
      fileFilter: (req, file, cb) => {
        console.log(
          'UPLOAD DEBUG mimetype:',
          file.mimetype,
          'filename:',
          file.originalname,
        );
        if (
          file.mimetype.startsWith('image/') ||
          file.originalname.match(/\.(jpg|jpeg|png|gif|bmp|webp)$/i)
        ) {
          cb(null, true);
        } else {
          cb(new Error('Only images are allowed!'), false);
        }
      },
    }),
  )
  uploadOfferImage(@UploadedFile() file: Express.Multer.File) {
    try {
      if (!file) throw new ForbiddenException('No file uploaded');
      const baseUrl = process.env.BASE_URL || 'http://192.168.100.6:3000';
      return { url: `${baseUrl}/uploads/offer-images/${file.filename}` };
    } catch (error) {
      console.error('Upload error:', error);
      throw error;
    }
  }
}
