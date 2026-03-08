import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LivreurUploadType } from './livreur-upload.constants';
import { LivreurProfile } from '@prisma/client';
import { LivreurProfileDto } from './dto/livreur-profile.dto';

@Injectable()
export class LivreurService {
  constructor(private readonly prisma: PrismaService) {}

  async updateProfile(
    userId: string,
    dto: LivreurProfileDto,
  ): Promise<LivreurProfile> {
    return this.prisma.livreurProfile.upsert({
      where: { userId },
      create: { userId, ...dto },
      update: { ...dto },
    });
  }

  async acceptTerms(userId: string, name?: string): Promise<LivreurProfile> {
    return this.prisma.livreurProfile.upsert({
      where: { userId },
      create: { userId, termsAcceptedAt: new Date(), termsAcceptedName: name },
      update: { termsAcceptedAt: new Date(), termsAcceptedName: name },
    });
  }

  async submit(userId: string): Promise<LivreurProfile> {
    return this.prisma.livreurProfile.upsert({
      where: { userId },
      create: { userId, submittedAt: new Date() },
      update: { submittedAt: new Date() },
    });
  }

  async saveUploadUrl(
    userId: string,
    type: LivreurUploadType,
    url: string,
  ): Promise<LivreurProfile> {
    const fieldMap: Record<LivreurUploadType, string> = {
      photo: 'photoUrl',
      license: 'licensePhotoUrl',
      ownership: 'vehicleOwnershipDocUrl',
      vehicle: 'vehiclePhotoUrl',
    };
    const field = fieldMap[type];
    if (!field) throw new BadRequestException('Invalid upload type');
    return this.prisma.livreurProfile.upsert({
      where: { userId },
      create: { userId, [field]: url },
      update: { [field]: url },
    });
  }
}
