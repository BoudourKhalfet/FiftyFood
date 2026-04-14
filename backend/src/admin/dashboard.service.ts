import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private prisma: PrismaService) {}

  async getDashboardStats() {
    // Total users by role (only active/approved)
    const usersByRole = await this.prisma.user.groupBy({
      where: {
        status: 'APPROVED',
      },
      by: ['role'],
      _count: {
        _all: true,
      },
    });

    // Total accounts by status
    const accountsByStatus = await this.prisma.user.groupBy({
      by: ['status'],
      _count: {
        id: true,
      },
    });

    // Total orders and revenue
    const orderStats = await this.prisma.order.aggregate({
      _count: {
        id: true,
      },
      _sum: {
        total: true,
      },
    });

    // Orders by status
    const ordersByStatus = await this.prisma.order.groupBy({
      by: ['status'],
      _count: {
        id: true,
      },
    });

    // Average ratings
    const avgRestaurantRating = await this.prisma.review.aggregate({
      where: {
        restaurantId: {
          not: null,
        },
      },
      _avg: {
        rating: true,
      },
    });

    const avgDelivererRating = await this.prisma.review.aggregate({
      where: {
        delivererId: {
          not: null,
        },
      },
      _avg: {
        rating: true,
      },
    });

    // Get restaurants with report statistics
    const restaurants = await this.prisma.user.findMany({
      where: { role: 'RESTAURANT' },
      select: {
        id: true,
        email: true,
        status: true,
        suspendedAt: true,
        restaurantProfile: {
          select: {
            restaurantName: true,
            address: true,
            city: true,
            avgRating: true,
          },
        },
        restaurantReviews: {
          select: {
            id: true,
            rating: true,
            comment: true,
            createdAt: true,
          },
        },
      },
    });

    // Calculate report percentage for each restaurant
    const restaurantStats = restaurants.map((rest) => {
      const totalReviews = rest.restaurantReviews.length;
      const negativeReviews = rest.restaurantReviews.filter((r) => r.rating <= 2).length;
      const reportPercentage = totalReviews > 0 ? (negativeReviews / totalReviews) * 100 : 0;

      return {
        id: rest.id,
        email: rest.email,
        status: rest.status,
        suspendedAt: rest.suspendedAt,
        name: rest.restaurantProfile?.restaurantName || 'Unknown',
        address: rest.restaurantProfile?.address,
        city: rest.restaurantProfile?.city,
        avgRating: rest.restaurantProfile?.avgRating || 0,
        totalReviews,
        negativeReviews,
        reportPercentage,
        isFlagged: reportPercentage > 20,
        recentReviews: rest.restaurantReviews
          .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
          .slice(0, 3),
      };
    });

    // Top flagged restaurants (>20%)
    const flaggedRestaurants = restaurantStats
      .filter((r) => r.isFlagged)
      .sort((a, b) => b.reportPercentage - a.reportPercentage);

    return {
      userStats: {
        byRole: usersByRole,
        byStatus: accountsByStatus,
        total: usersByRole.reduce((sum, r) => sum + (r._count?._all ?? 0), 0),
      },
      orderStats: {
        total: orderStats._count.id,
        totalRevenue: orderStats._sum.total || 0,
        byStatus: ordersByStatus,
      },
      ratingStats: {
        avgRestaurantRating: avgRestaurantRating._avg.rating || 0,
        avgDelivererRating: avgDelivererRating._avg.rating || 0,
      },
      restaurants: restaurantStats,
      flaggedRestaurants,
      dashboard: {
        totalRestaurants: restaurantStats.length,
        flaggedCount: flaggedRestaurants.length,
        approvedRestaurants: restaurantStats.filter((r) => r.status === 'APPROVED').length,
        avgReportPercentage: 
          restaurantStats.length > 0
            ? restaurantStats.reduce((sum, r) => sum + r.reportPercentage, 0) / restaurantStats.length
            : 0,
      },
    };
  }
}
