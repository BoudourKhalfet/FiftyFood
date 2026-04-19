/* eslint-disable @typescript-eslint/no-floating-promises */
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import * as crypto from 'crypto';
type PendingRoleFilter = 'RESTAURANT' | 'LIVREUR';

function sha256(input: string) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function getEmailPayloadKey(): Buffer {
  const secret =
    process.env.EMAIL_CREDENTIALS_SECRET ||
    process.env.JWT_SECRET ||
    'dev_secret_change_me';
  return crypto.createHash('sha256').update(secret).digest();
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
  ) {}

  private encryptWelcomePayload(payload: {
    email: string;
    password: string;
    roleLabel: string;
  }): string {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv(
      'aes-256-gcm',
      getEmailPayloadKey(),
      iv,
    );
    const encrypted = Buffer.concat([
      cipher.update(JSON.stringify(payload), 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    return `${iv.toString('base64url')}.${tag.toString('base64url')}.${encrypted.toString('base64url')}`;
  }

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
        legalAgreements: {
          select: {
            type: true,
            acceptedAt: true,
            signerName: true,
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
        legalAgreements: {
          select: {
            type: true,
            acceptedAt: true,
            signerName: true,
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

  async createUser(email: string, password: string, role: Role) {
    const allowed =
      role === Role.CLIENT || role === Role.LIVREUR || role === Role.RESTAURANT;

    if (!allowed) {
      throw new BadRequestException('Invalid role');
    }

    const emailLower = email.toLowerCase();

    const existing = await this.prisma.user.findUnique({
      where: { email: emailLower },
    });
    if (existing) throw new BadRequestException('Email already in use');

    const bcrypt = await import('bcrypt');
    const passwordHash = await bcrypt.hash(password, 10);
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    const tokenExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Admin-created users are approved immediately and then forced through email verification.
    const status = AccountStatus.APPROVED;

    // Admin-created accounts must verify email first
    const emailVerifiedAt = null;

    const user = await this.prisma.user.create({
      data: {
        email: emailLower,
        passwordHash,
        role,
        status,
        emailVerifiedAt,
        emailVerificationTokenHash: tokenHash,
        emailVerificationExpiresAt: tokenExpires,
        clientProfile:
          role === Role.CLIENT
            ? { create: { termsAcceptedAt: new Date() } }
            : undefined,
        restaurantProfile:
          role === Role.RESTAURANT ? { create: {} } : undefined,
        livreurProfile: role === Role.LIVREUR ? { create: {} } : undefined,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        emailVerifiedAt: true,
      },
    });

    // Send welcome email
    const baseUrl =
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.245.51:3000';
    const roleLabel =
      role === Role.CLIENT
        ? 'Client'
        : role === Role.RESTAURANT
          ? 'Restaurant'
          : 'Livreur';
    const welcomeToken = this.encryptWelcomePayload({
      email: user.email,
      password,
      roleLabel,
    });
    const verifyUrl = `${baseUrl}/auth/verify-email?token=${rawToken}&welcome=${encodeURIComponent(welcomeToken)}`;

    try {
      await this.mailService.sendMail(
        user.email,
        `Verify your email for FiftyFood (${roleLabel})`,
        `<h2>Verify your email</h2>
         <p>Your ${roleLabel} account has been created by an administrator.</p>
         <p>Please <a href="${verifyUrl}">click here to verify your email address</a>.</p>
         <p>After verification, you will receive a second email with your sign-in credentials.</p>
         <p>If you did not request this, please contact support.</p>`,
      );
    } catch (error) {
      console.error(
        'Failed to send verification email for admin-created user:',
        error,
      );
      // Don't throw - account creation succeeds even if email fails
    }

    const adminId = 'cmlz4rqup0000v1bcnh1zy7ps'; // Use actual admin id in real code
    await this.logHistory({
      userId: user.id,
      actorId: adminId,
      actorRole: 'ADMIN',
      action: 'APPROVE', // Log as creation/approval
    });

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      status: user.status,
      message: `${roleLabel} account created successfully`,
    };
  }

  async deleteUser(userId: string) {
    // Optionally: Check role/authorization, check existence
    return this.prisma.user.delete({
      where: { id: userId },
    });
  }
}
