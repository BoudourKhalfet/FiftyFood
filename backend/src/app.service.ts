import { Injectable } from '@nestjs/common';
import { AccountStatus, Role } from '@prisma/client';
import { PrismaService } from './prisma/prisma.service';

@Injectable()
export class AppService {
  constructor(private readonly prisma: PrismaService) {}

  getHello(): string {
    return 'Hello World!';
  }

  private sumItemQuantities(orders: { items: unknown }[]): number {
    return orders.reduce((total, order) => {
      const items = order.items as Array<{ quantity?: number }> | null;
      if (!Array.isArray(items)) return total;

      return total + items.reduce((sum, item) => sum + (item.quantity || 0), 0);
    }, 0);
  }

  async getHomepageStats() {
    const [activeUsers, partnerRestaurants, completedOrders] =
      await Promise.all([
        this.prisma.user.count({
          where: {
            role: Role.CLIENT,
            status: AccountStatus.APPROVED,
          },
        }),
        this.prisma.user.count({
          where: {
            role: Role.RESTAURANT,
            status: AccountStatus.APPROVED,
          },
        }),
        this.prisma.order.findMany({
          where: {
            status: { in: ['PICKED_UP', 'DELIVERED'] },
          },
          select: { items: true },
        }),
      ]);

    const mealsSaved = this.sumItemQuantities(completedOrders);
    const co2Reduced = Math.round(mealsSaved * 2.5 * 10) / 10;

    return {
      mealsSaved,
      activeUsers,
      partnerRestaurants,
      co2Reduced,
    };
  }
}
