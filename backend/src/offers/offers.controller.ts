import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Req,
  ForbiddenException,
  UseInterceptors,
  UploadedFile,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { Role } from '@prisma/client';

import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { GenerateDescriptionDto } from './dto/generate-description.dto';
import { AiVerifyPhotoDto } from './dto/ai-verify-photo.dto';
import { RecommendationService } from '../recommendations/recommendation.service';
import { Public } from '../auth/decorators/public.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';

type ReqWithUser = Request & { user: { sub: string; role: Role } };

@Controller('offers')
export class OffersController {
  constructor(
    private readonly offers: OffersService,
    private readonly recommendations: RecommendationService,
  ) {}

  private ensureRestaurant(req: ReqWithUser) {
    if (req.user.role !== Role.RESTAURANT) {
      throw new ForbiddenException('Only RESTAURANT can manage offers');
    }
  }

  /**
   * GET /offers
   * List all active, visible offers (public endpoint)
   */
  @Public()
  @Get()
  async getAvailableOffers() {
    return this.offers.getAvailableOffers();
  }

  /**
   * POST /offers/generate-description
   * Generate a commercial description for a food photo using Gemini.
   */
  @Post('generate-description')
  async generateDescription(
    @Req() req: ReqWithUser,
    @Body() dto: GenerateDescriptionDto,
  ) {
    this.ensureRestaurant(req);
    return this.offers.generateDescription(dto.imageUrl, dto.language || 'en');
  }

  /**
   * POST /offers/ai-verify-photo
   * Verify a food photo with AI (food check).
   */
  @Post('ai-verify-photo')
  @HttpCode(200)
  async aiVerifyPhoto(@Req() req: ReqWithUser, @Body() dto: AiVerifyPhotoDto) {
    this.ensureRestaurant(req);
    try {
      const result = await this.offers.verifyPhotoFromUrl(dto.imageUrl);
      return {
        isValid: result.passed === true,
        messages: result.messages ?? [],
        confidence: result.confidence ?? 0,
        skipped: result.skipped ?? false,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : 'Verification failed';
      console.error('AI verification error:', errorMsg);
      return {
        isValid: false,
        messages: [errorMsg],
        confidence: 0,
        skipped: false,
      };
    }
  }

  /**
   * POST /offers/upload-photo
   * Upload an offer photo
   */
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
  uploadOfferImage(
    @Req() req: Request,
    @UploadedFile() file: Express.Multer.File,
  ) {
    try {
      if (!file) {
        throw new ForbiddenException('Please select an image to upload');
      }

      const configuredBaseUrl =
        process.env.PUBLIC_BACKEND_URL || process.env.BASE_URL;
      const protocol =
        (req.headers['x-forwarded-proto'] as string | undefined) ||
        req.protocol;
      const host = req.get('host');
      const requestBaseUrl = host ? `${protocol}://${host}` : undefined;
      const baseUrl =
        configuredBaseUrl || requestBaseUrl || 'http://localhost:3000';
      return { url: `${baseUrl}/uploads/offer-images/${file.filename}` };
    } catch (error) {
      console.error('Upload error:', error);
      if (error instanceof ForbiddenException) {
        throw error;
      }
      throw new ForbiddenException('Failed to upload image. Please try again.');
    }
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
   * GET /offers/recommended
   * Personalised offer feed for the authenticated client.
   */
  @Get('recommended')
  @UseGuards(JwtAuthGuard)
  async getRecommendedOffers(@Req() req: ReqWithUser) {
    return this.recommendations.getRecommendedOffers(req.user.sub);
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
   * PATCH /offers/:id
   * Update editable offer fields (except photo).
   */
  @Patch(':id')
  async updateOffer(
    @Req() req: ReqWithUser,
    @Param('id') id: string,
    @Body() dto: UpdateOfferDto,
  ) {
    this.ensureRestaurant(req);
    return this.offers.updateOffer(req.user.sub, id, dto);
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

  /**
   * PATCH /offers/:id/decrement-quantity
   * Decrement offer quantity after a successful purchase.
   */
  @Patch(':id/decrement-quantity')
  @UseGuards(JwtAuthGuard)
  async decrementQuantity(
    @Req() req: ReqWithUser,
    @Param('id') id: string,
    @Body() body?: { quantity?: number },
  ) {
    return this.offers.decrementQuantity(id, body?.quantity ?? 1);
  }
}
