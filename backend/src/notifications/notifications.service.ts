import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { NotificationType, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from './push-notifications.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

type OrderForNotification = {
  id: string;
  orderCode: string;
  status: string;
  collectionMethod: string | null;
  clientId: string;
  restaurantId: string;
  livreurId: string | null;
  reference: string;
  updatedAt: Date;
  pickupTime: string | null;
  restaurantName: string;
  delivererName: string;
};

@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationsService.name);
  private reminderTimer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly pushNotifications: PushNotificationsService,
  ) {}

  async onModuleInit() {
    await this.dispatchReminderNotifications();
    this.reminderTimer = setInterval(() => {
      void this.dispatchReminderNotifications().catch((error: unknown) => {
        this.logger.error(
          'Failed to dispatch reminder notifications',
          error as Error,
        );
      });
    }, 60_000);
  }

  onModuleDestroy() {
    if (this.reminderTimer) {
      clearInterval(this.reminderTimer);
      this.reminderTimer = undefined;
    }
  }

  async listForUser(
    userId: string,
    options?: { unreadOnly?: boolean; limit?: number },
  ) {
    const limit = Math.min(Math.max(options?.limit ?? 50, 1), 100);

    return this.prisma.appNotification.findMany({
      where: {
        userId,
        ...(options?.unreadOnly ? { isRead: false } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async unreadCount(userId: string) {
    return this.prisma.appNotification.count({
      where: { userId, isRead: false },
    });
  }

  async registerDeviceToken(userId: string, dto: RegisterDeviceTokenDto) {
    return this.prisma.userDeviceToken.upsert({
      where: { token: dto.token },
      update: {
        userId,
        platform: dto.platform,
        revokedAt: null,
        lastSeenAt: new Date(),
      },
      create: {
        userId,
        token: dto.token,
        platform: dto.platform,
      },
      select: {
        id: true,
        token: true,
        platform: true,
        revokedAt: true,
        lastSeenAt: true,
      },
    });
  }

  async revokeDeviceToken(userId: string, token: string) {
    if (!token?.trim()) {
      throw new BadRequestException('Device token is required');
    }

    const result = await this.prisma.userDeviceToken.updateMany({
      where: {
        userId,
        token,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });

    return { updated: result.count };
  }

  async markRead(userId: string, notificationId: string) {
    const found = await this.prisma.appNotification.findUnique({
      where: { id: notificationId },
      select: { id: true, userId: true, isRead: true },
    });

    if (!found || found.userId !== userId) {
      throw new NotFoundException('Notification not found');
    }

    if (found.isRead) return found;

    return this.prisma.appNotification.update({
      where: { id: notificationId },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });
  }

  async markAllRead(userId: string) {
    const result = await this.prisma.appNotification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });

    return { updated: result.count };
  }

  async notifyOrderCreated(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order) return;

    await this.createNotification(order.clientId, {
      type: NotificationType.ORDER_STATUS_UPDATED,
      orderId: order.id,
      title: 'Order received',
      message: `Your order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} has been received. Complete your payment to confirm it.`,
      payload: { status: 'PENDING', orderId: order.id },
    });

    if (order.collectionMethod === 'DELIVERY') {
      await this.notifyNewDeliveryAvailable(order.id);
    }
  }

  async notifyOrderAssigned(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order) return;

    await this.createNotification(order.clientId, {
      type: NotificationType.ORDER_STATUS_UPDATED,
      orderId: order.id,
      title: 'Deliverer assigned',
      message: `${order.delivererName || 'A deliverer'} is handling your order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)}.`,
      payload: { status: 'ASSIGNED', orderId: order.id },
    });
  }

  async notifyOrderReady(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order) return;

    await this.createNotification(order.clientId, {
      type: NotificationType.ORDER_STATUS_UPDATED,
      orderId: order.id,
      title:
        order.collectionMethod === 'PICKUP'
          ? 'Order ready for pickup'
          : 'Order ready for deliverer pickup',
      message:
        order.collectionMethod === 'PICKUP'
          ? `Your order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} is ready at ${order.restaurantName}.`
          : `${order.restaurantName} marked order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} as ready.`,
      payload: { status: 'READY', orderId: order.id },
    });

    if (order.collectionMethod === 'DELIVERY' && order.livreurId) {
      await this.createNotification(order.livreurId, {
        type: NotificationType.ORDER_READY_FOR_DELIVERER,
        orderId: order.id,
        title: 'Order ready for pickup',
        message: `${order.restaurantName} marked order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} as ready.`,
        payload: { status: 'READY', orderId: order.id },
      });
    }
  }

  async notifyOrderPickedUp(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order) return;

    await this.createNotification(order.clientId, {
      type: NotificationType.ORDER_STATUS_UPDATED,
      orderId: order.id,
      title:
        order.collectionMethod === 'PICKUP'
          ? 'Order picked up'
          : 'Deliverer picked up your order',
      message:
        order.collectionMethod === 'PICKUP'
          ? `Order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} was marked as picked up.`
          : `${order.delivererName || 'Your deliverer'} picked up order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)}.`,
      payload: { status: 'PICKED_UP', orderId: order.id },
    });

    if (order.collectionMethod === 'DELIVERY') {
      await this.createNotification(order.clientId, {
        type: NotificationType.DELIVERY_CONFIRMATION_REMINDER,
        orderId: order.id,
        title: 'Confirm delivery when received',
        message: `When your order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} arrives, please confirm delivery in the app.`,
        payload: { action: 'confirm_delivery', orderId: order.id },
      });

      await this.prisma.order.update({
        where: { id: order.id },
        data: { deliveryConfirmReminderSentAt: new Date() },
      });
    }
  }

  async notifyOrderDelivered(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order) return;

    await this.createNotification(order.clientId, {
      type: NotificationType.ORDER_STATUS_UPDATED,
      orderId: order.id,
      title: 'Order delivered',
      message: `Order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} has been marked as delivered.`,
      payload: { status: 'DELIVERED', orderId: order.id },
    });

    if (order.reviewReminderSentAt == null) {
      await this.createNotification(order.clientId, {
        type: NotificationType.REVIEW_RESTAURANT_REMINDER,
        orderId: order.id,
        title: 'Review the restaurant',
        message: `Please rate ${order.restaurantName} for order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)}.`,
        payload: { action: 'review_restaurant', orderId: order.id },
      });

      if (order.collectionMethod === 'DELIVERY' && order.livreurId) {
        await this.createNotification(order.clientId, {
          type: NotificationType.REVIEW_DELIVERER_REMINDER,
          orderId: order.id,
          title: 'Review your deliverer',
          message: `Please rate ${order.delivererName || 'your deliverer'} for order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)}.`,
          payload: { action: 'review_deliverer', orderId: order.id },
        });
      }

      await this.prisma.order.update({
        where: { id: order.id },
        data: { reviewReminderSentAt: new Date() },
      });
    }
  }

  async notifyNewDeliveryAvailable(orderId: string) {
    const order = await this.getOrderContext(orderId);
    if (!order || order.collectionMethod !== 'DELIVERY') return;

    const users = await this.prisma.user.findMany({
      where: { role: Role.LIVREUR, status: 'APPROVED' },
      select: {
        id: true,
        livreurProfile: {
          select: {
            notificationPreferences: true,
          },
        },
      },
    });

    const targetIds = users
      .filter((u) => {
        const prefs = (u.livreurProfile?.notificationPreferences ??
          {}) as Record<string, unknown>;
        return prefs.newOffers !== false;
      })
      .map((u) => u.id);

    await Promise.all(
      targetIds.map((userId) =>
        this.createNotification(userId, {
          type: NotificationType.NEW_DELIVERY_AVAILABLE,
          orderId: order.id,
          title: 'New delivery available',
          message: `Order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} from ${order.restaurantName} is available.`,
          payload: { action: 'open_available_deliveries', orderId: order.id },
        }),
      ),
    );
  }

  private async dispatchReminderNotifications() {
    const orders = await this.prisma.order.findMany({
      where: {
        status: { in: ['CONFIRMED', 'ASSIGNED', 'READY', 'PICKED_UP'] },
      },
      select: {
        id: true,
        orderCode: true,
        reference: true,
        status: true,
        collectionMethod: true,
        clientId: true,
        livreurId: true,
        pickupReminderSentAt: true,
        delivererPickupReminderSentAt: true,
        offer: {
          select: {
            pickupTime: true,
            pickupDateTime: true,
            restaurant: {
              select: {
                restaurantProfile: { select: { restaurantName: true } },
              },
            },
          },
        },
      },
      take: 500,
    });

    const now = new Date();

    for (const order of orders) {
      const pickupStart = this.getPickupStart(
        order.offer?.pickupDateTime ?? null,
        order.offer?.pickupTime ?? null,
      );
      if (!pickupStart) continue;

      const minutesUntilPickup =
        (pickupStart.getTime() - now.getTime()) / 60_000;

      if (
        order.collectionMethod === 'PICKUP' &&
        order.pickupReminderSentAt == null &&
        (order.status === 'CONFIRMED' || order.status === 'READY') &&
        minutesUntilPickup >= 0 &&
        minutesUntilPickup <= 20
      ) {
        await this.createNotification(order.clientId, {
          type: NotificationType.PICKUP_REMINDER,
          orderId: order.id,
          title: 'Pickup time soon',
          message: `Your pickup for order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} is coming up soon.`,
          payload: { action: 'open_order', orderId: order.id },
        });

        await this.prisma.order.update({
          where: { id: order.id },
          data: { pickupReminderSentAt: new Date() },
        });
      }

      if (
        order.collectionMethod === 'DELIVERY' &&
        order.livreurId &&
        order.delivererPickupReminderSentAt == null &&
        order.status === 'ASSIGNED' &&
        minutesUntilPickup >= 0 &&
        minutesUntilPickup <= 20
      ) {
        const restaurantName =
          order.offer?.restaurant?.restaurantProfile?.restaurantName ??
          'the restaurant';

        await this.createNotification(order.livreurId, {
          type: NotificationType.DELIVERER_PICKUP_TIME_REMINDER,
          orderId: order.id,
          title: 'Pickup time is near',
          message: `Order ${this.displayOrderCode(order.orderCode, order.collectionMethod, order.reference)} pickup at ${restaurantName} is soon.`,
          payload: { action: 'open_active_delivery', orderId: order.id },
        });

        await this.prisma.order.update({
          where: { id: order.id },
          data: { delivererPickupReminderSentAt: new Date() },
        });
      }
    }
  }

  private async createNotification(
    userId: string,
    input: {
      type: NotificationType;
      title: string;
      message: string;
      orderId?: string;
      payload?: Record<string, unknown>;
    },
  ) {
    const saved = await this.prisma.appNotification.create({
      data: {
        userId,
        type: input.type,
        title: input.title,
        message: input.message,
        orderId: input.orderId,
        payload: input.payload as Prisma.InputJsonValue | undefined,
      },
    });

    const activeTokens = await this.prisma.userDeviceToken.findMany({
      where: { userId, revokedAt: null },
      select: { token: true },
    });

    const tokens = activeTokens.map((entry) => entry.token);
    if (tokens.length) {
      await this.pushNotifications.sendToTokens(tokens, saved);
    }

    return saved;
  }

  private displayOrderCode(
    orderCode?: string | null,
    collectionMethod?: string | null,
    reference?: string | null,
  ) {
    const normalizedCode = (orderCode ?? '').trim().toUpperCase();
    if (normalizedCode) {
      if ((collectionMethod ?? '').toUpperCase() === 'PICKUP') {
        return normalizedCode.replace(/^DEL/i, 'PUP');
      }

      return normalizedCode.replace(/^DEL/i, 'DEV');
    }

    const fallback = (reference ?? '').trim().toUpperCase();
    return fallback ? `#${fallback.slice(0, 8)}` : '#UNKNOWN';
  }

  private getPickupStart(
    pickupDateTime: Date | null,
    pickupTime: string | null,
  ): Date | null {
    if (!pickupDateTime) return null;

    const base = new Date(pickupDateTime);
    const raw = (pickupTime ?? '').trim();
    const slotStart = raw.includes('-') ? raw.split('-')[0].trim() : raw;
    const parts = slotStart.split(':');
    if (parts.length !== 2) return base;

    const hour = Number(parts[0]);
    const minute = Number(parts[1]);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return base;

    base.setHours(hour, minute, 0, 0);
    return base;
  }

  private async getOrderContext(
    orderId: string,
  ): Promise<
    (OrderForNotification & { reviewReminderSentAt: Date | null }) | null
  > {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        orderCode: true,
        status: true,
        collectionMethod: true,
        clientId: true,
        restaurantId: true,
        livreurId: true,
        reference: true,
        updatedAt: true,
        reviewReminderSentAt: true,
        offer: {
          select: {
            pickupDateTime: true,
            pickupTime: true,
            restaurant: {
              select: {
                restaurantProfile: { select: { restaurantName: true } },
              },
            },
          },
        },
        livreur: {
          select: {
            livreurProfile: { select: { fullName: true } },
          },
        },
      },
    });

    if (!order) return null;

    return {
      id: order.id,
      orderCode: order.orderCode,
      status: order.status,
      collectionMethod: order.collectionMethod,
      clientId: order.clientId,
      restaurantId: order.restaurantId,
      livreurId: order.livreurId,
      reference: order.reference,
      updatedAt: order.updatedAt,
      reviewReminderSentAt: order.reviewReminderSentAt,
      pickupTime: order.offer?.pickupTime ?? null,
      restaurantName:
        order.offer?.restaurant?.restaurantProfile?.restaurantName ??
        'Restaurant',
      delivererName: order.livreur?.livreurProfile?.fullName ?? '',
    };
  }
}
