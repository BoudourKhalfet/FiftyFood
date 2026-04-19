import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LivreurUploadType } from './livreur-upload.constants';
import { LivreurProfile, Role } from '@prisma/client';
import { LivreurProfileDto } from './dto/livreur-profile.dto';

@Injectable()
export class LivreurService {
  constructor(private readonly prisma: PrismaService) {}

  async updateProfile(
    userId: string,
    dto: LivreurProfileDto,
  ): Promise<LivreurProfile> {
    const profileData = {
      fullName: dto.fullName,
      phone: dto.phone,
      vehicleType: dto.vehicleType,
      zone: dto.zone,
      cinOrPassportNumber: dto.cinOrPassportNumber,
      bankAccountNumber: dto.bankAccountNumber,
      licensePhotoUrl: dto.licensePhotoUrl,
      vehicleOwnershipDocUrl: dto.vehicleOwnershipDocUrl,
      vehiclePhotoUrl: dto.vehiclePhotoUrl,
      payoutMethod: dto.payoutMethod,
      payoutDetails: dto.payoutDetails,
    };
    return this.prisma.livreurProfile.upsert({
      where: { userId },
      create: { userId, ...profileData },
      update: { ...profileData },
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

  async setLocationConsent(userId: string, consented: boolean) {
    // Only LIVREUR should call this
    return this.prisma.livreurProfile.update({
      where: { userId },
      data: {
        locationConsentGiven: consented,
        locationConsentGivenAt: new Date(),
      },
    });
  }

  async updateNotifications(
    userId: string,
    notificationPreferences: {
      newOffers?: boolean;
      orderUpdates?: boolean;
    },
  ) {
    await this.prisma.$executeRaw`
      UPDATE "LivreurProfile"
      SET "notificationPreferences" = ${JSON.stringify(notificationPreferences)}::jsonb,
          "updatedAt" = NOW()
      WHERE "userId" = ${userId}
    `;

    return this.prisma.livreurProfile.findUnique({
      where: { userId },
    });
  }

  async getLivreurProfile(userId: string): Promise<LivreurProfile> {
    const profile = await this.prisma.livreurProfile.findUnique({
      where: { userId },
    });
    if (!profile) throw new NotFoundException('Livreur profile not found');
    return profile;
  }

  async pingOnline(userId: string): Promise<LivreurProfile> {
    // Update lastOnlineAt to now for this livreur
    return this.prisma.livreurProfile.update({
      where: { userId },
      data: {
        lastOnlineAt: new Date(),
      },
    });
  }

  async updateLocation(userId: string, latitude: number, longitude: number) {
    const profile = await this.prisma.livreurProfile.findUnique({
      where: { userId },
      select: { id: true, locationConsentGiven: true },
    });

    if (!profile) throw new NotFoundException('Livreur profile not found');
    if (!profile.locationConsentGiven) {
      throw new BadRequestException('Location consent is required');
    }

    return this.prisma.livreurProfile.update({
      where: { userId },
      data: {
        lastLatitude: latitude,
        lastLongitude: longitude,
        lastLocationAt: new Date(),
        lastOnlineAt: new Date(),
      },
    });
  }

  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== Role.LIVREUR) {
      throw new ForbiddenException('Only LIVREUR account can be deleted here');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.order.updateMany({
        where: { livreurId: userId },
        data: { livreurId: null },
      });

      await tx.review.deleteMany({
        where: {
          OR: [{ reviewerId: userId }, { delivererId: userId }],
        },
      });

      await tx.user.delete({
        where: { id: userId },
      });
    });

    return { message: 'Account deleted.' };
  }
}
