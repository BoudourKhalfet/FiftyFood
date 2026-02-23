import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
type PendingRoleFilter = 'RESTAURANT' | 'LIVREUR';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async listPending(role?: PendingRoleFilter) {
    const roleFilter =
      role === 'RESTAURANT'
        ? Role.RESTAURANT
        : role === 'LIVREUR'
          ? Role.LIVREUR
          : undefined;

    const baseWhere = {
      status: AccountStatus.PENDING,
      role: roleFilter ? roleFilter : { in: [Role.RESTAURANT, Role.LIVREUR] },
      emailVerifiedAt: { not: null }, // keeps only verified
    };

    return this.prisma.user.findMany({
      where: {
        ...baseWhere,

        // Only show submitted restaurant applications
        ...(roleFilter === Role.RESTAURANT
          ? { restaurantProfile: { is: { submittedAt: { not: null } } } }
          : {}),

        // For LIVREUR, once you create LivreurProfile with submittedAt,
        // add a similar filter here.
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        statusReason: true,
        emailVerifiedAt: true,
        createdAt: true,
        restaurantProfile: {
          select: {
            restaurantName: true,
            establishmentType: true,
            city: true,
            submittedAt: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  private ensureApprovableRole(role: Role) {
    if (role !== Role.RESTAURANT && role !== Role.LIVREUR) {
      throw new BadRequestException(
        'Only RESTAURANT/LIVREUR accounts require approval.',
      );
    }
  }

  async approveUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    this.ensureApprovableRole(user.role);

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.APPROVED,
        statusReason: null,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        statusReason: true,
      },
    });
  }

  async rejectUser(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    this.ensureApprovableRole(user.role);

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.REJECTED,
        statusReason: reason,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        statusReason: true,
      },
    });
  }

  async requireChanges(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    this.ensureApprovableRole(user.role);

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.CHANGES_REQUIRED,
        statusReason: reason,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        statusReason: true,
      },
    });
  }

  async suspendClient(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.CLIENT) {
      throw new BadRequestException('This endpoint suspends CLIENT only.');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        suspendedAt: new Date(),
        statusReason: reason,
      },
      select: {
        id: true,
        email: true,
        role: true,
        suspendedAt: true,
        statusReason: true,
      },
    });
  }

  async unsuspendClient(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.CLIENT) {
      throw new BadRequestException('This endpoint unsuspends CLIENT only.');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { suspendedAt: null },
      select: { id: true, email: true, role: true, suspendedAt: true },
    });
  }
}
