import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RestaurantIdentityDto } from './dto/restaurant-identity.dto';
import { RestaurantLegalDto } from './dto/restaurant-legal.dto';
import { RestaurantPayoutDto } from './dto/restaurant-payout.dto';
import { RestaurantUploadType } from './uploads/restaurants-upload.constants';
import { RestaurantProfile } from '@prisma/client';

@Injectable()
export class RestaurantsService {
  constructor(private readonly prisma: PrismaService) {}

  async updateIdentity(userId: string, dto: RestaurantIdentityDto) {
    return this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        restaurantName: dto.restaurantName,
        establishmentType: dto.establishmentType,
        phone: dto.phone,
        address: dto.address,
        city: dto.city,
        identityCompletedAt: new Date(),
      },
    });
  }

  async updateLegal(userId: string, dto: RestaurantLegalDto) {
    return this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        legalEntityName: dto.legalEntityName,
        registrationNumberRNE: dto.registrationNumberRNE.trim(),
        ownershipType: dto.ownershipType,
        legalCompletedAt: new Date(),
      },
    });
  }

  async updatePayout(userId: string, dto: RestaurantPayoutDto) {
    return this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        payoutMethod: dto.payoutMethod,
        payoutDetails: dto.payoutDetails,
        payoutCompletedAt: new Date(),
      },
    });
  }

  async saveUploadUrl(userId: string, type: RestaurantUploadType, url: string) {
    const data =
      type === 'logo'
        ? { logoUrl: url }
        : type === 'cover'
          ? { coverImageUrl: url }
          : type === 'business-registration'
            ? { businessRegistrationDocumentUrl: url }
            : type === 'hygiene-certificate'
              ? { hygieneCertificateUrl: url }
              : type === 'proof-of-ownership'
                ? { proofOfOwnershipOrLeaseUrl: url }
                : null;

    if (!data) throw new BadRequestException('Invalid upload type');

    return this.prisma.restaurantProfile.update({
      where: { userId },
      data,
    });
  }

  async acceptTerms(userId: string, name?: string): Promise<RestaurantProfile> {
    return this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        termsAcceptedAt: new Date(),
        termsAcceptedName: name,
      },
    });
  }

  async submit(userId: string) {
    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });

    if (!profile) throw new BadRequestException('Restaurant profile not found');

    const missing: string[] = [];
    if (!profile.restaurantName) missing.push('restaurantName');
    if (!profile.establishmentType) missing.push('establishmentType');
    if (!profile.phone) missing.push('phone');
    if (!profile.address) missing.push('address');
    if (!profile.city) missing.push('city');

    if (!profile.legalEntityName) missing.push('legalEntityName');
    if (!profile.registrationNumberRNE) missing.push('registrationNumberRNE');
    if (!profile.ownershipType) missing.push('ownershipType');

    if (!profile.businessRegistrationDocumentUrl)
      missing.push('businessRegistrationDocumentUrl');
    if (!profile.hygieneCertificateUrl) missing.push('hygieneCertificateUrl');

    if (missing.length) {
      throw new BadRequestException({
        code: 'ONBOARDING_INCOMPLETE',
        missing,
      });
    }

    return this.prisma.restaurantProfile.update({
      where: { userId },
      data: { submittedAt: new Date() },
    });
  }
}
