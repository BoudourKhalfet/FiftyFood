import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  Param,
} from '@nestjs/common';
import {
  LIVREUR_UPLOAD_TYPES,
  LivreurUploadType,
} from './livreur-upload.constants';
import { Role, LivreurProfile } from '@prisma/client';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { join } from 'path';
import { LivreurService } from './livreur.service';
import { OnboardingAuthGuard } from '../auth/guards/onboarding-auth.guard';
import { LivreurProfileDto } from './dto/livreur-profile.dto';
import { ensureDir } from '../restaurants/uploads/ensure-dir';
import type { Request } from 'express';

type ReqWithUser = Request & { user: { sub: string; role: Role } };

@Controller('livreur/onboarding')
@UseGuards(OnboardingAuthGuard)
export class LivreurOnboardingController {
  constructor(private readonly livreur: LivreurService) {}

  private ensureLivreur(req: ReqWithUser) {
    if (req.user.role !== Role.LIVREUR)
      throw new ForbiddenException('Only LIVREUR allowed');
  }

  @Patch('profile')
  updateProfile(
    @Req() req: ReqWithUser,
    @Body() dto: LivreurProfileDto,
  ): Promise<LivreurProfile> {
    this.ensureLivreur(req);
    return this.livreur.updateProfile(req.user.sub, dto);
  }

  @Post('accept-terms')
  acceptTerms(@Req() req: ReqWithUser): Promise<LivreurProfile> {
    this.ensureLivreur(req);
    return this.livreur.acceptTerms(req.user.sub);
  }

  @Post('submit')
  submit(@Req() req: ReqWithUser): Promise<LivreurProfile> {
    this.ensureLivreur(req);
    return this.livreur.submit(req.user.sub);
  }

  @Post('upload/:type')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (req: Request, _file, cb) => {
          const r = req as ReqWithUser;
          const dest = join(process.cwd(), 'uploads', 'livreurs', r.user.sub);
          ensureDir(dest);
          cb(null, dest);
        },
        filename: (req: Request, file, cb) => {
          const typeParam = req.params.type as LivreurUploadType;
          if (!LIVREUR_UPLOAD_TYPES.includes(typeParam))
            return cb(new Error('Invalid upload type'), '');
          const slug = `${typeParam}-${Date.now()}-${file.originalname.replace(/\s/g, '-')}`;
          cb(null, slug);
        },
      }),
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const allowed = ['image/png', 'image/jpeg', 'application/pdf'];
        if (!allowed.includes(file.mimetype)) {
          return cb(
            new BadRequestException('Unsupported file type') as Error,
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async upload(
    @Req() req: ReqWithUser,
    @Param('type') type: LivreurUploadType,
    @UploadedFile() file?: Express.Multer.File,
  ): Promise<LivreurProfile> {
    this.ensureLivreur(req);
    if (!LIVREUR_UPLOAD_TYPES.includes(type))
      throw new BadRequestException('Invalid upload type');
    if (!file) throw new BadRequestException('Missing file');
    const url = `/uploads/livreurs/${req.user.sub}/${file.filename}`;
    return this.livreur.saveUploadUrl(req.user.sub, type, url);
  }
}
