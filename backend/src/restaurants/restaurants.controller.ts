import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Param,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import type { Request } from 'express';
import { Role } from '@prisma/client';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { join } from 'path';

import { RestaurantsService } from './restaurants.service';
import { OnboardingAuthGuard } from '../auth/guards/onboarding-auth.guard';
import { RestaurantIdentityDto } from './dto/restaurant-identity.dto';
import { RestaurantLegalDto } from './dto/restaurant-legal.dto';
import { RestaurantPayoutDto } from './dto/restaurant-payout.dto';
import {
  RESTAURANT_UPLOAD_TYPES,
  RestaurantUploadType,
} from './uploads/restaurants-upload.constants';
import {
  getRestaurantUploadFilename,
  makeRestaurantUploadPublicUrl,
} from './uploads/restaurants-upload.util';
import { ensureDir } from './uploads/ensure-dir';

type ReqWithUser = Request & { user: { sub: string; role: Role } };

@Controller('restaurant/onboarding')
@UseGuards(OnboardingAuthGuard)
export class RestaurantsController {
  constructor(private readonly restaurants: RestaurantsService) {}

  private ensureRestaurant(req: ReqWithUser) {
    if (req.user.role !== Role.RESTAURANT) {
      throw new ForbiddenException('Only RESTAURANT can access this resource');
    }
  }

  @Patch('identity')
  updateIdentity(@Req() req: ReqWithUser, @Body() dto: RestaurantIdentityDto) {
    this.ensureRestaurant(req);
    return this.restaurants.updateIdentity(req.user.sub, dto);
  }

  @Patch('legal')
  updateLegal(@Req() req: ReqWithUser, @Body() dto: RestaurantLegalDto) {
    this.ensureRestaurant(req);
    return this.restaurants.updateLegal(req.user.sub, dto);
  }

  @Patch('payout')
  updatePayout(@Req() req: ReqWithUser, @Body() dto: RestaurantPayoutDto) {
    this.ensureRestaurant(req);
    return this.restaurants.updatePayout(req.user.sub, dto);
  }

  @Post('submit')
  submit(@Req() req: ReqWithUser) {
    this.ensureRestaurant(req);
    return this.restaurants.submit(req.user.sub);
  }

  @Post('upload/:type')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (
          req: Request,
          _file: Express.Multer.File,
          cb: (error: Error | null, destination: string) => void,
        ) => {
          const r = req as unknown as ReqWithUser;
          const dest = join(
            process.cwd(),
            'uploads',
            'restaurants',
            r.user.sub,
          );
          ensureDir(dest);
          cb(null, dest);
        },
        filename: (
          req: Request,
          file: Express.Multer.File,
          cb: (error: Error | null, filename: string) => void,
        ) => {
          const type = (req as Request & { params: { type?: string } }).params
            .type;
          if (!RESTAURANT_UPLOAD_TYPES.includes(type as RestaurantUploadType)) {
            return cb(new Error('Invalid upload type'), '');
          }

          cb(
            null,
            getRestaurantUploadFilename(
              type as RestaurantUploadType,
              file.originalname,
            ),
          );
        },
      }),
      limits: {
        fileSize: 5 * 1024 * 1024, // 5MB
      },
      fileFilter: (
        _req: Request,
        file: Express.Multer.File,
        cb: (error: Error | null, acceptFile: boolean) => void,
      ) => {
        const allowed = ['image/png', 'image/jpeg', 'application/pdf'];
        if (!allowed.includes(file.mimetype)) {
          return cb(
            new BadRequestException(
              'Unsupported file type',
            ) as unknown as Error,
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async upload(
    @Req() req: ReqWithUser,
    @Param('type') type: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    this.ensureRestaurant(req);

    if (!RESTAURANT_UPLOAD_TYPES.includes(type as RestaurantUploadType)) {
      throw new BadRequestException('Invalid upload type');
    }
    if (!file) throw new BadRequestException('Missing file');

    const url = makeRestaurantUploadPublicUrl(req.user.sub, file.filename);

    return this.restaurants.saveUploadUrl(
      req.user.sub,
      type as RestaurantUploadType,
      url,
    );
  }
}
