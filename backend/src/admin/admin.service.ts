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
            commissionRate: true,
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
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.1.15:3000';
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

  async getComplaintsReport() {
    type RestaurantWithStats = {
      id: string;
      email: string;
      status: string;
      suspendedAt: Date | null;
      restaurantProfile: { restaurantName: string | null; avgRating: number | null } | null;
      restaurantOrders: { id: string }[];
      restaurantComplaints: { id: string; reason: string }[];
    };

    type DelivererWithStats = {
      id: string;
      email: string;
      status: string;
      suspendedAt: Date | null;
      livreurProfile: { fullName: string | null; avgRating: number | null } | null;
      livreurOrders: { id: string }[];
      delivererComplaints: { id: string; reason: string }[];
    };

    // Get all restaurants with their orders, complaints and profile
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
            avgRating: true,
          },
        },
        restaurantOrders: {
          where: {
            status: { in: ['PICKED_UP', 'DELIVERED'] }
          },
          select: { id: true },
        },
        restaurantComplaints: {
          select: { id: true, reason: true },
        },
      },
    }) as RestaurantWithStats[];

    // Get all deliverers with their orders, complaints and profile
    const deliverers = await this.prisma.user.findMany({
      where: { role: 'LIVREUR' },
      select: {
        id: true,
        email: true,
        status: true,
        suspendedAt: true,
        livreurProfile: {
          select: {
            fullName: true,
            avgRating: true,
          },
        },
        livreurOrders: {
          where: {
            status: { in: ['PICKED_UP', 'DELIVERED'] }
          },
          select: { id: true },
        },
        delivererComplaints: {
          select: { id: true, reason: true },
        },
      },
    }) as DelivererWithStats[];

    type ComplaintWithRelations = {
      id: string;
      reason: string;
      description: string | null;
      createdAt: Date;
      restaurantId: string | null;
      delivererId: string | null;
      orderId: string | null;
      order: { reference: string | null; orderCode: string | null } | null;
      complainant: { email: string; clientProfile: { fullName: string | null } | null } | null;
      restaurant: { restaurantProfile: { restaurantName: string | null } | null } | null;
      deliverer: { livreurProfile: { fullName: string | null } | null } | null;
    };

    // Get all complaints with relations
    const complaints = await this.prisma.complaint.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        reason: true,
        description: true,
        createdAt: true,
        restaurantId: true,
        delivererId: true,
        orderId: true,
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
              select: { fullName: true },
            },
          },
        },
        restaurant: {
          select: {
            restaurantProfile: {
              select: { restaurantName: true },
            },
          },
        },
        deliverer: {
          select: {
            livreurProfile: {
              select: { fullName: true },
            },
          },
        },
      },
    }) as ComplaintWithRelations[];

    // Get complaint categories by target type
    const allComplaints = await this.prisma.complaint.findMany({
      select: {
        reason: true,
        restaurantId: true,
      },
    });

    const categoriesMap = new Map<string, { reason: string; targetType: string; count: number }>();
    
    for (const c of allComplaints) {
      const targetType = c.restaurantId ? 'RESTAURANT' : 'DELIVERER';
      const key = `${c.reason}|${targetType}`;
      const existing = categoriesMap.get(key);
      if (existing) {
        existing.count++;
      } else {
        categoriesMap.set(key, { reason: c.reason, targetType, count: 1 });
      }
    }

    const complaintCategories = Array.from(categoriesMap.values())
      .sort((a, b) => b.count - a.count);

    // Format restaurant stats
    const restaurantStats = restaurants.map((r) => {
      // Aggregate complaint reasons for this restaurant
      const complaintReasons: Record<string, number> = {};
      for (const c of r.restaurantComplaints) {
        complaintReasons[c.reason] = (complaintReasons[c.reason] || 0) + 1;
      }

      return {
        id: r.id,
        restaurantName: r.restaurantProfile?.restaurantName || 'Unknown',
        email: r.email,
        status: r.status,
        suspendedAt: r.suspendedAt?.toISOString() || null,
        totalOrders: r.restaurantOrders.length,
        totalComplaints: r.restaurantComplaints.length,
        avgRating: r.restaurantProfile?.avgRating || 0,
        complaintCategories: Object.entries(complaintReasons)
          .map(([reason, count]) => ({ reason, count }))
          .sort((a, b) => b.count - a.count),
      };
    });

    // Format deliverer stats
    const delivererStats = deliverers.map((d) => {
      // Aggregate complaint reasons for this deliverer
      const complaintReasons: Record<string, number> = {};
      for (const c of d.delivererComplaints) {
        complaintReasons[c.reason] = (complaintReasons[c.reason] || 0) + 1;
      }

      return {
        id: d.id,
        delivererName: d.livreurProfile?.fullName || 'Unknown',
        email: d.email,
        status: d.status,
        suspendedAt: d.suspendedAt?.toISOString() || null,
        totalOrders: d.livreurOrders.length,
        totalComplaints: d.delivererComplaints.length,
        avgRating: d.livreurProfile?.avgRating || 0,
        complaintCategories: Object.entries(complaintReasons)
          .map(([reason, count]) => ({ reason, count }))
          .sort((a, b) => b.count - a.count),
      };
    });

    // Format complaints
    const formattedComplaints = complaints.map((c) => ({
      id: c.id,
      reason: c.reason,
      description: c.description,
      createdAt: c.createdAt.toISOString(),
      restaurantId: c.restaurantId,
      delivererId: c.delivererId,
      orderId: c.orderId,
      orderReference: c.order?.reference || null,
      orderCode: c.order?.orderCode || null,
      complainantEmail: c.complainant?.email || null,
      complainantName: c.complainant?.clientProfile?.fullName || null,
      restaurantName: c.restaurant?.restaurantProfile?.restaurantName || null,
      delivererName: c.deliverer?.livreurProfile?.fullName || null,
    }));

    return {
      complaints: formattedComplaints,
      restaurantStats,
      delivererStats,
      complaintCategories,
    };
  }

  async getCommissionRate(restaurantId: string) {
    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId: restaurantId },
      select: { commissionRate: true },
    });
    if (!profile) throw new NotFoundException('Restaurant not found');
    return { commissionRate: profile.commissionRate };
  }

  async updateCommissionRate(restaurantId: string, commissionRate: number) {
    if (commissionRate < 0 || commissionRate > 100) {
      throw new BadRequestException('Commission rate must be between 0 and 100');
    }

    const profile = await this.prisma.restaurantProfile.findUnique({
      where: { userId: restaurantId },
    });
    if (!profile) throw new NotFoundException('Restaurant not found');

    await this.prisma.restaurantProfile.update({
      where: { userId: restaurantId },
      data: { commissionRate },
    });

    return { success: true, commissionRate };
  }

  async getRestaurantOrders(restaurantId: string) {
    const restaurant = await this.prisma.user.findUnique({
      where: { id: restaurantId },
      select: {
        restaurantProfile: { select: { restaurantName: true } },
      },
    });

    if (!restaurant || !restaurant.restaurantProfile) {
      throw new NotFoundException('Restaurant not found');
    }

    // Return EXACT same format as mobile app
    // CRITICAL: Once order is CONFIRMED, show it forever regardless of status
    const orders = await this.prisma.order.findMany({
      where: {
        restaurantId,
        status: { in: ['CONFIRMED', 'ASSIGNED', 'READY', 'PICKED_UP', 'DELIVERED'] },
      },
      include: {
        client: { include: { clientProfile: true } },
        reviews: {
          select: { rating: true },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totalRevenue = orders.reduce((sum, order) => sum + order.total, 0);

    return {
      restaurantName: restaurant.restaurantProfile.restaurantName,
      totalRevenue,
      orders: orders.map(order => ({
        id: order.id,
        orderCode: order.orderCode,
        total: order.total,
        deliveryFee: order.deliveryFee ?? 0,
        status: order.status,
        createdAt: order.createdAt,
        customerName: order.client?.clientProfile?.fullName ?? '',
        rating: order.reviews?.[0]?.rating ?? null,
      })),
    };
  }

  async getDelivererOrders(delivererId: string) {
    const deliverer = await this.prisma.user.findUnique({
      where: { id: delivererId },
      select: {
        livreurProfile: { select: { fullName: true } },
      },
    });

    if (!deliverer || !deliverer.livreurProfile) {
      throw new NotFoundException('Deliverer not found');
    }

    // Return EXACT same format as mobile app - fixed deliverer earning per order
    const orders = await this.prisma.order.findMany({
      where: {
        livreurId: delivererId,
        // Show all orders from CONFIRMED onwards
        status: { in: ['CONFIRMED', 'ASSIGNED', 'READY', 'PICKED_UP', 'DELIVERED'] }
      },
      include: {
        restaurant: { include: { restaurantProfile: true } },
        client: { include: { clientProfile: true } },
        reviews: {
          select: { rating: true },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    // Transform data to match mobile app format
    const transformedOrders = orders.map((order) => ({
      id: order.id,
      orderCode: order.orderCode || '',
      restaurantName: order.restaurant?.restaurantProfile?.restaurantName || '',
      customerName: order.client?.clientProfile?.fullName || '',
      date: order.updatedAt,
      amount: 2.5,
      deliveryFee: 0,
      total: 2.5,
      rating: order.reviews?.[0]?.rating || null,
      status: order.status,
      deliveryAddress: order.deliveryAddress || '',
    }));

    // Total earnings = sum of all amounts (no fees deducted)
    const totalEarnings = transformedOrders.reduce((sum, order) => sum + (order.amount || 0), 0);

    return {
      delivererName: deliverer.livreurProfile.fullName,
      totalEarnings,
      orders: transformedOrders,
    };
  }
}
