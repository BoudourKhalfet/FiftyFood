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
          "longitude" = ${coords.lng}
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
              "longitude" = ${coords.lng}
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

  async getMonthlyHistory(userId: string) {
    const now = new Date();
    const result: { month: string; revenue: number; mealsSaved: number }[] = [];

    for (let i = 5; i >= 0; i--) {
      const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const start = new Date(date.getFullYear(), date.getMonth(), 1);
      const end = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);

      const agg = await this.prisma.order.aggregate({
        where: {
          restaurantId: userId,
          status: { in: ['DELIVERED'] },
          createdAt: { gte: start, lte: end },
        },
        _sum: { total: true },
      });

      const completedOrders = await this.prisma.order.findMany({
        where: {
          restaurantId: userId,
          status: { in: ['PICKED_UP', 'DELIVERED'] },
          createdAt: { gte: start, lte: end },
        },
        select: { items: true },
      });
      const mealsSaved = completedOrders.reduce((total, order) => {
        const items = order.items as Array<{ quantity?: number }> | null;
        if (!Array.isArray(items)) return total;
        return total + items.reduce((sum, item) => sum + (item.quantity || 0), 0);
      }, 0);

      result.push({
        month: date.toLocaleString('en-US', { month: 'short' }),
        revenue: Math.round((agg._sum?.total || 0) * 100) / 100,
        mealsSaved,
      });
    }

    return result;
  }

  async getPickupsPerHour(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: {
        restaurantId: userId,
        status: { in: ['PICKED_UP', 'DELIVERED'] },
        collectionMethod: 'PICKUP',
      },
      select: { createdAt: true },
    });

    const map: Record<number, number> = {};
    for (const order of orders) {
      const hour = new Date(order.createdAt).getHours();
      map[hour] = (map[hour] || 0) + 1;
    }

    const hours = Object.keys(map).map(Number).sort((a, b) => a - b);
    return hours.map((h) => ({ hour: `${h}h`, count: map[h] }));
  }

  async getRatingsDistribution(userId: string) {
    const rows = await this.prisma.review.groupBy({
      by: ['rating'],
      where: { restaurantId: userId },
      _count: { rating: true },
    });

    const map: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    for (const row of rows) {
      if (row.rating >= 1 && row.rating <= 5) {
        map[row.rating] = row._count.rating;
      }
    }

    const total = Object.values(map).reduce((s, v) => s + v, 0);
    return {
      total,
      distribution: [5, 4, 3, 2, 1].map((stars) => ({ stars, count: map[stars] })),
    };
  }

  async getWeeklyChartData(userId: string) {
    const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const now = new Date();
    const result: { day: string; revenue: number; orders: number }[] = [];

    for (let i = 6; i >= 0; i--) {
      const start = new Date(now);
      start.setDate(now.getDate() - i);
      start.setHours(0, 0, 0, 0);

      const end = new Date(start);
      end.setHours(23, 59, 59, 999);

      const agg = await this.prisma.order.aggregate({
        where: {
          restaurantId: userId,
          status: { in: ['DELIVERED', 'PICKED_UP'] },
          createdAt: { gte: start, lte: end },
        },
        _sum: { total: true },
        _count: { id: true },
      });

      result.push({
        day: DAYS[start.getDay()],
        revenue: Math.round((agg._sum?.total || 0) * 100) / 100,
        orders: agg._count?.id || 0,
      });
    }

    return result;
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

    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId },
      select: { id: true, avgRating: true, restaurantName: true },
    });

    if (!profile) {
      throw new BadRequestException('Restaurant profile not found');
    }

    const now = new Date();
    const d7ago = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const d14ago = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

    const completedStatuses = { in: ['PICKED_UP', 'DELIVERED'] as any[] };

    // Helper to sum item quantities from orders
    const sumItemQuantities = (orders: { items: unknown }[]): number => {
      return orders.reduce((total, order) => {
        const items = order.items as Array<{ quantity?: number }> | null;
        if (!Array.isArray(items)) return total;
        return total + items.reduce((sum, item) => sum + (item.quantity || 0), 0);
      }, 0);
    };

    // Total stats
    const totalOrderData = await this.prisma.order.aggregate({
      where: { restaurantId: userId, status: { in: ['DELIVERED'] } },
      _sum: { total: true },
    });
    const totalCompletedOrders = await this.prisma.order.findMany({
      where: { restaurantId: userId, status: completedStatuses },
      select: { items: true },
    });
    const totalMealsSaved = sumItemQuantities(totalCompletedOrders);
    const totalOrders = await this.prisma.order.count({
      where: { restaurantId: userId },
    });
    const activeOffersCount = await this.prisma.offer.count({
      where: { restaurantId: userId, status: 'ACTIVE', pickupDateTime: { gte: now } },
    });

    // Last 7 days
    const data7d = await this.prisma.order.aggregate({
      where: { restaurantId: userId, status: { in: ['DELIVERED'] }, createdAt: { gte: d7ago } },
      _sum: { total: true },
      _count: { id: true },
    });
    const completedOrders7d = await this.prisma.order.findMany({
      where: { restaurantId: userId, status: completedStatuses, createdAt: { gte: d7ago } },
      select: { items: true },
    });
    const meals7d = sumItemQuantities(completedOrders7d);
    const completedOrdersPrev7d = await this.prisma.order.findMany({
      where: { restaurantId: userId, status: completedStatuses, createdAt: { gte: d14ago, lt: d7ago } },
      select: { items: true },
    });
    const mealsPrev7d = sumItemQuantities(completedOrdersPrev7d);

    // Previous 7 days (for % change)
    const dataPrev7d = await this.prisma.order.aggregate({
      where: { restaurantId: userId, status: { in: ['DELIVERED'] }, createdAt: { gte: d14ago, lt: d7ago } },
      _sum: { total: true },
      _count: { id: true },
    });

    // Avg rating: current 7d vs previous 7d from reviews
    const ratingCurr = await this.prisma.review.aggregate({
      where: { restaurantId: userId, createdAt: { gte: d7ago } },
      _avg: { rating: true },
    });
    const ratingPrev = await this.prisma.review.aggregate({
      where: { restaurantId: userId, createdAt: { gte: d14ago, lt: d7ago } },
      _avg: { rating: true },
    });

    const revenue7d = data7d._sum?.total || 0;
    const orders7d = data7d._count?.id || 0;
    const prevRevenue = dataPrev7d._sum?.total || 0;
    const prevOrders = dataPrev7d._count?.id || 0;
    const avgCurr = ratingCurr._avg?.rating ?? null;
    const avgPrev = ratingPrev._avg?.rating ?? null;

    const pctChange = (curr: number, prev: number) =>
      prev === 0 ? 0 : Math.round(((curr - prev) / prev) * 1000) / 10;
    const pointChange = (curr: number | null, prev: number | null) =>
      curr === null || prev === null ? 0 : Math.round((curr - prev) * 10) / 10;

    return {
      totalSales: totalOrderData._sum?.total || 0,
      totalOrders,
      totalMealsSaved,
      restaurantName: profile.restaurantName || '',
      avgRating: profile.avgRating || 0,
      activeOffers: activeOffersCount,
      revenue7d,
      orders7d,
      mealsSaved7d: meals7d,
      revenueChangePercent: pctChange(revenue7d, prevRevenue),
      ordersChangePercent: pctChange(orders7d, prevOrders),
      mealsSavedChangePercent: pctChange(meals7d, mealsPrev7d),
      avgRatingChange: pointChange(avgCurr, avgPrev),
    };
  }
}
