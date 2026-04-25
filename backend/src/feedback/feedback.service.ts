import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { CreateComplaintDto } from './dto/create-complaint.dto';
import { CreateRestaurantReviewDto } from './dto/create-restaurant-review.dto';

type TargetType = 'RESTAURANT' | 'DELIVERER';

type ComplaintRow = {
  id: string;
  reason: string;
  description: string | null;
  createdAt: Date;
  order: { reference: string | null; orderCode: string | null } | null;
  complainant: {
    email: string;
    clientProfile: { fullName: string | null } | null;
  } | null;
};

type ComplaintDelegate = {
  findFirst(args: {
    where: {
      orderId: string;
      complainantId: string;
      restaurantId: string | null;
      delivererId: string | null;
    };
    select: { id: true };
  }): Promise<{ id: string } | null>;
  update(args: {
    where: { id: string };
    data: { reason: string; description: string | null };
  }): Promise<unknown>;
  create(args: {
    data: {
      orderId: string;
      complainantId: string;
      restaurantId: string | null;
      delivererId: string | null;
      reason: string;
      description: string | null;
    };
  }): Promise<unknown>;
  findMany(args: {
    where: { restaurantId?: string; delivererId?: string };
    orderBy: { createdAt: 'desc' };
    take: number;
    select: {
      id: true;
      reason: true;
      description: true;
      createdAt: true;
      order: { select: { reference: true; orderCode: true } };
      complainant: {
        select: {
          email: true;
          clientProfile: { select: { fullName: true } };
        };
      };
    };
  }): Promise<ComplaintRow[]>;
};

@Injectable()
export class FeedbackService {
  constructor(private readonly prisma: PrismaService) {}

  private complaintDelegate() {
    const delegate = (
      this.prisma as unknown as { complaint: ComplaintDelegate }
    ).complaint;
    if (!delegate) {
      throw new ServiceUnavailableException(
        'Complaint feature is not ready. Run Prisma migration and regenerate client.',
      );
    }
    return delegate;
  }

  private async loadClientOrder(orderId: string, clientId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        clientId: true,
        restaurantId: true,
        livreurId: true,
        status: true,
        collectionMethod: true,
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    if (order.clientId !== clientId) {
      throw new ForbiddenException(
        'You can only leave feedback for your own orders',
      );
    }

    return order;
  }

  private ensureFeedbackAllowed(
    order: {
      status: string;
      collectionMethod: string | null;
      livreurId: string | null;
    },
    targetType: TargetType,
  ) {
    const status = order.status.toUpperCase();
    const method = (order.collectionMethod ?? '').toUpperCase();

    if (targetType === 'RESTAURANT') {
      const isPickupReady =
        method === 'PICKUP' && ['PICKED_UP', 'DELIVERED'].includes(status);
      const isDeliveryDone = method === 'DELIVERY' && status === 'DELIVERED';
      if (!isPickupReady && !isDeliveryDone) {
        throw new BadRequestException(
          'Restaurant feedback is allowed only after pickup/delivery is completed',
        );
      }
      return;
    }

    if (method !== 'DELIVERY' || !order.livreurId) {
      throw new BadRequestException(
        'Deliverer feedback is only available for delivery orders with an assigned deliverer',
      );
    }

    if (status !== 'DELIVERED') {
      throw new BadRequestException(
        'Deliverer feedback is allowed only after delivery is completed',
      );
    }
  }

  private async recalculateRestaurantRating(restaurantUserId: string) {
    const aggregate = await this.prisma.review.aggregate({
      where: { restaurantId: restaurantUserId },
      _avg: { rating: true },
    });

    await this.prisma.restaurantProfile.updateMany({
      where: { userId: restaurantUserId },
      data: { avgRating: aggregate._avg.rating ?? 0 },
    });
  }

  private async recalculateDelivererRating(delivererUserId: string) {
    const aggregate = await this.prisma.review.aggregate({
      where: { delivererId: delivererUserId },
      _avg: { rating: true },
    });

    await this.prisma.livreurProfile.updateMany({
      where: { userId: delivererUserId },
      data: { avgRating: aggregate._avg.rating ?? 0 },
    });
  }

  async submitReview(clientId: string, dto: CreateReviewDto) {
    const order = await this.loadClientOrder(dto.orderId, clientId);
    this.ensureFeedbackAllowed(order, dto.targetType);

    const targetRestaurantId =
      dto.targetType === 'RESTAURANT' ? order.restaurantId : null;
    const targetDelivererId =
      dto.targetType === 'DELIVERER' ? order.livreurId : null;

    const existing = await this.prisma.review.findFirst({
      where: {
        orderId: dto.orderId,
        reviewerId: clientId,
        restaurantId: targetRestaurantId,
        delivererId: targetDelivererId,
      },
      select: { id: true },
    });

    const comment = dto.comment?.trim() ?? '';

    if (existing) {
      await this.prisma.review.update({
        where: { id: existing.id },
        data: {
          rating: dto.rating,
          comment,
        },
      });
    } else {
      await this.prisma.review.create({
        data: {
          orderId: dto.orderId,
          reviewerId: clientId,
          restaurantId: targetRestaurantId,
          delivererId: targetDelivererId,
          rating: dto.rating,
          comment,
        },
      });
    }

    if (targetRestaurantId) {
      await this.recalculateRestaurantRating(targetRestaurantId);
    }
    if (targetDelivererId) {
      await this.recalculateDelivererRating(targetDelivererId);
    }

    return { message: 'Review submitted successfully' };
  }

  async submitRestaurantReview(
    clientId: string,
    dto: CreateRestaurantReviewDto,
  ) {
    const restaurant = await this.prisma.restaurantProfile.findUnique({
      where: { userId: dto.restaurantId },
      select: { id: true },
    });

    if (!restaurant) {
      throw new NotFoundException('Restaurant not found');
    }

    const existing = await this.prisma.review.findFirst({
      where: {
        orderId: null,
        reviewerId: clientId,
        restaurantId: dto.restaurantId,
        delivererId: null,
      },
      select: { id: true },
    });

    const comment = dto.comment?.trim() ?? '';

    if (existing) {
      await this.prisma.review.update({
        where: { id: existing.id },
        data: {
          rating: dto.rating,
          comment,
        },
      });
    } else {
      await this.prisma.review.create({
        data: {
          reviewerId: clientId,
          restaurantId: dto.restaurantId,
          delivererId: null,
          rating: dto.rating,
          comment,
        },
      });
    }

    await this.recalculateRestaurantRating(dto.restaurantId);

    return { message: 'Review submitted successfully' };
  }

  async submitComplaint(clientId: string, dto: CreateComplaintDto) {
    const order = await this.loadClientOrder(dto.orderId, clientId);
    this.ensureFeedbackAllowed(order, dto.targetType);

    const targetRestaurantId =
      dto.targetType === 'RESTAURANT' ? order.restaurantId : null;
    const targetDelivererId =
      dto.targetType === 'DELIVERER' ? order.livreurId : null;

    const complaint = this.complaintDelegate();

    const existing = await complaint.findFirst({
      where: {
        orderId: dto.orderId,
        complainantId: clientId,
        restaurantId: targetRestaurantId,
        delivererId: targetDelivererId,
      },
      select: { id: true },
    });

    if (existing) {
      await complaint.update({
        where: { id: existing.id },
        data: {
          reason: dto.reason.trim(),
          description: dto.description?.trim() ?? null,
        },
      });
    } else {
      await complaint.create({
        data: {
          orderId: dto.orderId,
          complainantId: clientId,
          restaurantId: targetRestaurantId,
          delivererId: targetDelivererId,
          reason: dto.reason.trim(),
          description: dto.description?.trim() ?? null,
        },
      });
    }

    return { message: 'Complaint submitted successfully' };
  }

  async getReceivedReviews(userId: string, role: Role, limit: number) {
    if (role !== Role.RESTAURANT && role !== Role.LIVREUR) {
      throw new ForbiddenException(
        'Only restaurants and deliverers can access received reviews',
      );
    }

    const where =
      role === Role.RESTAURANT
        ? { restaurantId: userId }
        : { delivererId: userId };

    const reviews = await this.prisma.review.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        rating: true,
        comment: true,
        createdAt: true,
        order: {
          select: {
            reference: true,
            orderCode: true,
          },
        },
        reviewer: {
          select: {
            email: true,
            clientProfile: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });

    return reviews.map((item) => ({
      id: item.id,
      rating: item.rating,
      comment: item.comment,
      createdAt: item.createdAt,
      reviewerName: (() => {
        const fullName = item.reviewer?.clientProfile?.fullName?.trim() ?? '';
        return fullName || item.reviewer?.email || '';
      })(),
      orderReference: item.order?.reference ?? item.order?.orderCode ?? '',
    }));
  }

  async getReceivedComplaints(userId: string, role: Role, limit: number) {
    if (role !== Role.RESTAURANT && role !== Role.LIVREUR) {
      throw new ForbiddenException(
        'Only restaurants and deliverers can access received complaints',
      );
    }

    const where =
      role === Role.RESTAURANT
        ? { restaurantId: userId }
        : { delivererId: userId };
    const complaint = this.complaintDelegate();

    const complaints = await complaint.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        reason: true,
        description: true,
        createdAt: true,
        order: {
          select: {
            reference: true,
            orderCode: true,
          },
        },
        complainant: {
          select: {
            email: true,
            clientProfile: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });

    return complaints.map((item) => ({
      id: item.id,
      reason: item.reason,
      description: item.description,
      createdAt: item.createdAt,
      complainantName: (() => {
        const fullName =
          item.complainant?.clientProfile?.fullName?.trim() ?? '';
        return fullName || item.complainant?.email || '';
      })(),
      orderReference: item.order?.reference ?? item.order?.orderCode ?? '',
    }));
  }
}
