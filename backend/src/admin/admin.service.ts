/* eslint-disable @typescript-eslint/no-floating-promises */
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

  async listAll(role?: PendingRoleFilter) {
    const roleFilter =
      role === 'RESTAURANT'
        ? Role.RESTAURANT
        : role === 'LIVREUR'
          ? Role.LIVREUR
          : role === 'CLIENT'
            ? Role.CLIENT
            : undefined;

    // Assign the result to 'users'
    const users = await this.prisma.user.findMany({
      where: {
        role: roleFilter ? roleFilter : { in: [Role.RESTAURANT, Role.LIVREUR] },
        emailVerifiedAt: { not: null },
        ...(roleFilter === Role.RESTAURANT
          ? { restaurantProfile: { is: { submittedAt: { not: null } } } }
          : {}),
        ...(roleFilter === Role.LIVREUR
          ? { livreurProfile: { is: { submittedAt: { not: null } } } }
          : {}),
        ...(roleFilter === Role.CLIENT
          ? { clientProfile: { is: { joinedAt: { not: null } } } }
          : {}),
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        statusReason: true,
        emailVerifiedAt: true,
        createdAt: true,
        accountHistory: {
          select: {
            id: true,
            userId: true,
            actorId: true,
            actorRole: true,
            action: true,
            field: true,
            oldValue: true,
            newValue: true,
            reason: true,
            createdAt: true,
          },
          orderBy: { createdAt: 'asc' },
        },
        restaurantProfile: {
          select: {
            restaurantName: true,
            establishmentType: true,
            phone: true,
            legalEntityName: true,
            registrationNumberRNE: true,
            city: true,
            address: true,
            logoUrl: true,
            coverImageUrl: true,
            submittedAt: true,
            businessRegistrationDocumentUrl: true,
            hygieneCertificateUrl: true,
            proofOfOwnershipOrLeaseUrl: true,
            termsAcceptedAt: true,
            termsAcceptedName: true,
          },
        },
        livreurProfile: {
          select: {
            fullName: true,
            phone: true,
            cinOrPassportNumber: true,
            vehicleType: true,
            zone: true,
            licensePhotoUrl: true,
            vehicleOwnershipDocUrl: true,
            vehiclePhotoUrl: true,
            submittedAt: true,
          },
        },
        clientProfile: {
          select: {
            fullName: true,
            phone: true,
            defaultAddress: true,
            joinedAt: true,
            submittedAt: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    console.log('Returning these users:', users);

    return users;
  }

  async logHistory({
    userId,
    actorId,
    actorRole,
    action,
    field,
    oldValue,
    newValue,
    reason,
  }: {
    userId: string;
    actorId: string;
    actorRole: string; // "ADMIN" or "USER"
    action:
      | 'SUSPEND'
      | 'UNSUSPEND'
      | 'APPROVE'
      | 'REJECT'
      | 'REQUIRE_CHANGES'
      | 'PROFILE_EDIT';
    field?: string;
    oldValue?: string;
    newValue?: string;
    reason?: string;
  }) {
    return this.prisma.accountHistory.create({
      data: {
        userId,
        actorId,
        actorRole,
        action,
        field,
        oldValue,
        newValue,
        reason,
      },
    });
  }

  async suspendRestaurant(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.RESTAURANT) {
      throw new BadRequestException('This endpoint suspends RESTAURANT only.');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.SUSPENDED, // ensure this is an enum or string as used in your DB
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

    this.mailService.sendMail(
      user.email,
      'Votre compte restaurant FiftyFood a été suspendu',
      `<p>Bonjour,<br>Votre compte restaurant vient d'être <b>suspendu</b>. Raison : ${reason}</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'SUSPEND',
      reason,
    });
    return updatedUser;
  }

  async unsuspendRestaurant(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role !== Role.RESTAURANT) {
      throw new BadRequestException(
        'This endpoint unsuspends RESTAURANT only.',
      );
    }

    // Determine which status to revert to (e.g., APPROVED)
    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.APPROVED, // or whatever "reactivated" means
        statusReason: null,
      },
      select: { id: true, email: true, role: true, status: true },
    });

    this.mailService.sendMail(
      user.email,
      'Votre compte restaurant FiftyFood a été réactivé',
      `<p>Bonjour,<br>Votre compte restaurant est maintenant <b>réactivé</b>.</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'UNSUSPEND',
    });
    return updatedUser;
  }

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
            businessRegistrationDocumentUrl: true,
            hygieneCertificateUrl: true,
            proofOfOwnershipOrLeaseUrl: true,
            termsAcceptedAt: true,
            termsAcceptedName: true,
            phone: true,
            address: true,
            legalEntityName: true,
            registrationNumberRNE: true,
            // add trustScore here if it's a field
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

    this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été approuvé !',
      `<p>Bonjour,<br>Votre compte a été <b>approuvé</b>. Vous pouvez maintenant vous connecter à FiftyFood.</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'APPROVE',
    });

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

    this.mailService.sendMail(
      user.email,
      'Votre demande FiftyFood a été refusée',
      `<p>Bonjour,<br>Votre demande a été <b>refusée</b>.<br>Raison : ${reason}</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'REJECT',
      reason,
    });
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

    this.mailService.sendMail(
      user.email,
      'Des modifications sont requises sur votre compte FiftyFood',
      `<p>Bonjour,<br>Des modifications sont requises avant validation finale.<br>Raison : ${reason}</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'REQUIRE_CHANGES',
      reason,
    });
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
        status: AccountStatus.SUSPENDED,
        suspendedAt: new Date(),
        statusReason: reason,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        suspendedAt: true,
        statusReason: true,
      },
    });

    this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été suspendu',
      `<p>Bonjour,<br>Votre compte client vient d'être <b>suspendu</b>. Raison : ${reason}</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'SUSPEND',
      reason,
    });
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
      data: {
        suspendedAt: null,
        status: AccountStatus.APPROVED,
        statusReason: null,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        suspendedAt: true,
        statusReason: true,
      },
    });

    this.mailService.sendMail(
      user.email,
      'Votre compte FiftyFood a été réactivé',
      `<p>Bonjour,<br>Votre compte client est maintenant <b>réactivé</b>.</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use the actual admin user id in real code!

    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'UNSUSPEND',
    });

    return updatedUser;

    return updatedUser;
  }

  async suspendLivreur(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== Role.LIVREUR) {
      throw new BadRequestException('This endpoint suspends LIVREUR only.');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.SUSPENDED,
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

    // Mail (optional)
    this.mailService.sendMail(
      user.email,
      'Votre compte livreur FiftyFood a été suspendu',
      `<p>Bonjour,<br>Votre compte livreur vient d'être <b>suspendu</b>. Raison : ${reason}</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Replace with actual admin id
    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'SUSPEND',
      reason,
    });

    return updatedUser;
  }

  async unsuspendLivreur(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== Role.LIVREUR) {
      throw new BadRequestException('This endpoint unsuspends LIVREUR only.');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: AccountStatus.APPROVED,
        statusReason: null,
      },
      select: { id: true, email: true, role: true, status: true },
    });

    // Mail (optional)
    this.mailService.sendMail(
      user.email,
      'Votre compte livreur FiftyFood a été réactivé',
      `<p>Bonjour,<br>Votre compte livreur est maintenant <b>réactivé</b>.</p>`,
    );

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Replace with actual admin id
    await this.logHistory({
      userId,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'UNSUSPEND',
    });

    return updatedUser;
  }

  async getAccountHistoryForUser(userId: string) {
    return this.prisma.accountHistory.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async deleteUser(userId: string) {
    // Optionally: Check role/authorization, check existence
    return this.prisma.user.delete({
      where: { id: userId },
    });
  }
}
