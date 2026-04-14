import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RestaurantIdentityDto } from './dto/restaurant-identity.dto';
import { RestaurantLegalDto } from './dto/restaurant-legal.dto';
import { RestaurantPayoutDto } from './dto/restaurant-payout.dto';
import { RestaurantUploadType } from './uploads/restaurants-upload.constants';
import { RestaurantProfile } from '@prisma/client';

export type PublicReview = {
  user: string;
  rating: number;
  comment: string;
  date: Date;
};

export type RawReviewResult = {
  reviewer: { email: string };
  rating: number;
  comment: string;
  createdAt: Date;
};

@Injectable()
export class RestaurantsService {
  constructor(private readonly prisma: PrismaService) {}

  async logProfileChanges<T>(
    userId: string,
    dto: T,
    oldProfile: Record<string, any> | null, // <= this works!
    fields: (keyof T)[],
    actorRole: string = 'RESTAURANT',
  ) {
    // Only log changes if the profile has been submitted previously
    const hasBeenSubmitted = !!(oldProfile && oldProfile.submittedAt);
    if (!hasBeenSubmitted) return; // Don't log if profile hasn't been submitted

    for (const field of fields) {
      // Only log if field changes and is not undefined
      if (
        dto[field] !== undefined &&
        dto[field] !== oldProfile?.[field as string]
      ) {
        await this.prisma.accountHistory.create({
          data: {
            userId,
            action: 'PROFILE_EDIT',
            field: field as string,
            oldValue:
              oldProfile && oldProfile[field as string] != null
                ? String(oldProfile[field as string])
                : null,
            newValue: dto[field] != null ? String(dto[field]) : null,
            actorId: userId,
            actorRole,
          },
        });
      }
    }
  }

  async updateIdentity(userId: string, dto: RestaurantIdentityDto) {
    const oldProfile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });

    const updatedProfile = await this.prisma.restaurantProfile.update({
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

    await this.logProfileChanges(
      userId,
      dto,
      oldProfile,
      ['restaurantName', 'establishmentType', 'phone', 'address', 'city'],
      'RESTAURANT',
    );

    return updatedProfile;
  }

  async updateLegal(userId: string, dto: RestaurantLegalDto) {
    const oldProfile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });

    const updatedProfile = await this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        legalEntityName: dto.legalEntityName,
        registrationNumberRNE: dto.registrationNumberRNE.trim(),
        ownershipType: dto.ownershipType,
        legalCompletedAt: new Date(),
      },
    });

    await this.logProfileChanges(
      userId,
      dto,
      oldProfile,
      ['legalEntityName', 'registrationNumberRNE', 'ownershipType'],
      'RESTAURANT',
    );

    return updatedProfile;
  }

  async updatePayout(userId: string, dto: RestaurantPayoutDto) {
    const oldProfile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });

    const updatedProfile = await this.prisma.restaurantProfile.update({
      where: { userId },
      data: {
        payoutMethod: dto.payoutMethod,
        payoutDetails: dto.payoutDetails,
        payoutCompletedAt: new Date(),
      },
    });

    await this.logProfileChanges(
      userId,
      dto,
      oldProfile,
      [
        'payoutMethod',
        'payoutDetails',
        // add more payout fields as needed
      ],
      'RESTAURANT',
    );

    return updatedProfile;
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

  // New signature: also take agreements!
  async acceptTerms(
    userId: string,
    name: string,
    agreements: { type: string; accepted: boolean }[],
  ): Promise<RestaurantProfile> {
    // 1. Save legacy termsAcceptedAt/termsAcceptedName, or remove if not needed
    await this.prisma.restaurantProfile.update({
      where: { userId },
      data: {},
    });

    // 2. (Good practice!) Remove existing agreements for this user, to avoid duplicates:
    await this.prisma.legalAgreement.deleteMany({ where: { userId } });

    // 3. Insert an agreement for each checked agreement
    for (const ag of agreements) {
      if (ag.accepted) {
        await this.prisma.legalAgreement.create({
          data: {
            userId,
            type: ag.type,
            acceptedAt: new Date(),
            signerName: name,
            content: '', // Or the agreement text if you want to store it (optional)
          },
        });
      }
    }

    // 4. Optionally: return latest profile
    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });
    if (!profile) throw new BadRequestException('Profile not found');
    return profile;
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

  async findRestaurantById(id: string) {
    console.log('findRestaurantById INPUT:', id);
    let profile = await this.prisma.restaurantProfile.findUnique({
      where: { id },
    });
    if (profile) {
      console.log('[Profile found by id]', id, profile);
    }
    if (!profile) {
      profile = await this.prisma.restaurantProfile.findUnique({
        where: { userId: id },
      });
      if (profile) {
        console.log('[Profile found by userId]', id, profile);
      } else {
        console.log('[No profile found for id or userId]', id);
      }
    }
    return profile;
  }

  async findReviewsForRestaurant(
    restaurantId: string,
  ): Promise<PublicReview[]> {
    const reviews = (await this.prisma.review.findMany({
      where: { restaurantId },
      orderBy: { createdAt: 'desc' },
      select: {
        reviewer: { select: { email: true } },
        rating: true,
        comment: true,
        createdAt: true,
      },
    })) as RawReviewResult[];
    return reviews.map((r) => ({
      user: r.reviewer.email,
      rating: r.rating,
      comment: r.comment,
      date: r.createdAt,
    }));
  }

  async getRestaurantStats(userId: string) {
    // Get restaurant profile for avgRating
    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
      select: { id: true, avgRating: true },
    });

    if (!profile) {
      throw new BadRequestException('Restaurant profile not found');
    }

    // Get total sales from delivered orders
    const orderData = await this.prisma.order.aggregate({
      where: {
        restaurantId: userId,
        status: 'DELIVERED',
      },
      _sum: { total: true },
    });

    // Get meals saved (sum of quantities from all offers)
    const offerData = await this.prisma.offer.aggregate({
      where: { restaurantId: userId },
      _sum: { quantity: true },
    });

    // Get count of active offers
    const activeOffersCount = await this.prisma.offer.count({
      where: { restaurantId: userId, status: 'ACTIVE' },
    });

    return {
      totalSales: orderData._sum?.total || 0,
      mealsSaved: offerData._sum?.quantity || 0,
      avgRating: profile.avgRating || 0,
      activeOffers: activeOffersCount,
    };
  }
}
