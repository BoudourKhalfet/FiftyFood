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
  reviewer: {
    email: string;
    clientProfile: { fullName: string | null } | null;
  };
  rating: number;
  comment: string;
  createdAt: Date;
};

@Injectable()
export class RestaurantsService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeText(value?: string | null): string {
    return (value ?? '').trim().toLowerCase();
  }

  private async geocodeAddress(
    address: string,
    city: string,
  ): Promise<{ lat: number; lng: number } | null> {
    const query = [address, city]
      .filter((v) => !!this.normalizeText(v))
      .join(', ');
    if (!query) return null;

    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(query)}`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'FiftyFood/1.0 (restaurant-geocoding)',
        },
      });
      if (!response.ok) return null;

      const rows = (await response.json()) as Array<{
        lat: string;
        lon: string;
      }>;
      if (!rows.length) return null;

      const lat = Number(rows[0].lat);
      const lng = Number(rows[0].lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

      return { lat, lng };
    } catch {
      return null;
    }
  }

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

    // Best-effort geocoding of restaurant address to persist coordinates.
    const coords = await this.geocodeAddress(dto.address, dto.city);
    if (coords) {
      await this.prisma.$executeRaw`
        UPDATE "RestaurantProfile"
        SET
          "latitude" = ${coords.lat},
          "longitude" = ${coords.lng},
          "lastGeocodedAt" = NOW()
        WHERE "userId" = ${userId}
      `;
    }

    return updatedProfile;
  }

  async updateAccountProfile(
    userId: string,
    dto: Partial<RestaurantIdentityDto>,
  ) {
    const oldProfile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
    });

    const data: {
      restaurantName?: string;
      phone?: string;
      address?: string;
      city?: string;
    } = {};

    if (dto.restaurantName !== undefined) {
      data.restaurantName = dto.restaurantName;
    }
    if (dto.phone !== undefined) {
      data.phone = dto.phone;
    }
    if (dto.address !== undefined) {
      data.address = dto.address;
    }
    if (dto.city !== undefined) {
      data.city = dto.city;
    }

    const updatedProfile = await this.prisma.restaurantProfile.update({
      where: { userId },
      data,
    });

    await this.logProfileChanges(
      userId,
      dto,
      oldProfile,
      ['restaurantName', 'phone', 'address', 'city'],
      'RESTAURANT',
    );

    // Best-effort geocoding when address data changes.
    if (dto.address !== undefined || dto.city !== undefined) {
      const geocodeAddress = dto.address ?? updatedProfile.address;
      const geocodeCity = dto.city ?? updatedProfile.city;
      if (geocodeAddress && geocodeCity) {
        const coords = await this.geocodeAddress(geocodeAddress, geocodeCity);
        if (coords) {
          await this.prisma.$executeRaw`
            UPDATE "RestaurantProfile"
            SET
              "latitude" = ${coords.lat},
              "longitude" = ${coords.lng},
              "lastGeocodedAt" = NOW()
            WHERE "userId" = ${userId}
          `;
        }
      }
    }

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

  async deleteAccount(userId: string): Promise<{ message: string }> {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: 'SUSPENDED',
        suspendedAt: new Date(),
        statusReason: 'deleted',
      },
    });

    return { message: 'Account deleted.' };
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
      data: {
        termsAcceptedAt: new Date(),
        termsAcceptedName: name,
      },
    });

    // Remove existing agreements for this user to avoid duplicates.
    await this.prisma.legalAgreement.deleteMany({ where: { userId } });

    // Insert an agreement for each checked agreement.
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
        reviewer: {
          select: {
            email: true,
            clientProfile: { select: { fullName: true } },
          },
        },
        rating: true,
        comment: true,
        createdAt: true,
      },
    })) as RawReviewResult[];
    return reviews.map((r) => ({
      user: r.reviewer.clientProfile?.fullName?.trim() ?? r.reviewer.email,
      rating: r.rating,
      comment: r.comment,
      date: r.createdAt,
    }));
  }

  async getRestaurantStats(userId: string) {
    await this.prisma.offer.updateMany({
      where: {
        restaurantId: userId,
        status: 'ACTIVE',
        pickupDateTime: { lt: new Date() },
      },
      data: { status: 'EXPIRED' },
    });

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

    // Meals saved metric is the number of completed orders
    const completedOrdersCount = await this.prisma.order.count({
      where: {
        restaurantId: userId,
        status: { in: ['PICKED_UP', 'DELIVERED'] },
      },
    });

    // Get count of active offers
    const activeOffersCount = await this.prisma.offer.count({
      where: {
        restaurantId: userId,
        status: 'ACTIVE',
        pickupDateTime: { gte: new Date() },
      },
    });

    return {
      totalSales: orderData._sum?.total || 0,
      mealsSaved: completedOrdersCount,
      avgRating: profile.avgRating || 0,
      activeOffers: activeOffersCount,
    };
  }
}
