import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
type PendingRoleFilter = 'RESTAURANT' | 'LIVREUR';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
  ) {}

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
      emailVerifiedAt: { not: null },
    };

    return this.prisma.user.findMany({
      where: {
        ...baseWhere,
        ...(roleFilter === Role.RESTAURANT
          ? { restaurantProfile: { is: { submittedAt: { not: null } } } }
          : {}),
        // For LIVREUR: add similar filter if needed
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

    const updatedUser = await this.prisma.user.update({
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

    await this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été approuvé !',
      `<p>Bonjour,<br>Votre compte a été <b>approuvé</b>. Vous pouvez maintenant vous connecter à FiftyFood.</p>`,
    );
    return updatedUser;
  }

  async rejectUser(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    this.ensureApprovableRole(user.role);

    const updatedUser = await this.prisma.user.update({
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

    await this.mailService.sendMail(
      user.email,
      'Votre demande FiftyFood a été refusée',
      `<p>Bonjour,<br>Votre demande a été <b>refusée</b>.<br>Raison : ${reason}</p>`,
    );
    return updatedUser;
  }

  async requireChanges(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    this.ensureApprovableRole(user.role);

    const updatedUser = await this.prisma.user.update({
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

    await this.mailService.sendMail(
      user.email,
      'Des modifications sont requises sur votre compte FiftyFood',
      `<p>Bonjour,<br>Des modifications sont requises avant validation finale.<br>Raison : ${reason}</p>`,
    );
    return updatedUser;
  }

  async suspendClient(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.CLIENT) {
      throw new BadRequestException('This endpoint suspends CLIENT only.');
    }

    const updatedUser = await this.prisma.user.update({
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

    await this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été suspendu',
      `<p>Bonjour,<br>Votre compte client vient d'être <b>suspendu</b>. Raison : ${reason}</p>`,
    );
    return updatedUser;
  }

  async unsuspendClient(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.CLIENT) {
      throw new BadRequestException('This endpoint unsuspends CLIENT only.');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: { suspendedAt: null },
      select: { id: true, email: true, role: true, suspendedAt: true },
    });

    await this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été réactivé',
      `<p>Bonjour,<br>Votre compte client est maintenant <b>réactivé</b>.</p>`,
    );
    return updatedUser;
  }
}
