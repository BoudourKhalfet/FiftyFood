import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AccountStatus, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { JwtService } from '@nestjs/jwt';

function sha256(input: string) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const allowed =
      dto.role === Role.CLIENT ||
      dto.role === Role.LIVREUR ||
      dto.role === Role.RESTAURANT;

    if (!allowed) {
      throw new BadRequestException('Invalid role for self registration');
    }

    const email = dto.email.toLowerCase();

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new BadRequestException('Email already in use');

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const status =
      dto.role === Role.CLIENT ? AccountStatus.APPROVED : AccountStatus.PENDING;

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        role: dto.role,
        status,
        emailVerifiedAt: null,
        emailVerificationTokenHash: tokenHash,
        emailVerificationExpiresAt: expires,

        // Create empty role profiles at registration (so later steps can just "update")
        clientProfile: dto.role === Role.CLIENT ? { create: {} } : undefined,
        restaurantProfile:
          dto.role === Role.RESTAURANT ? { create: {} } : undefined,
        // TODO (later): livreurProfile: dto.role === Role.LIVREUR ? { create: {} } : undefined,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        emailVerifiedAt: true,
      },
    });

    const baseUrl = process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000';
    const verifyUrl = `${baseUrl}/auth/verify-email?token=${rawToken}`;
    // eslint-disable-next-line no-console
    console.log(`[DEV] Verify email for ${user.email}: ${verifyUrl}`);

    // Onboarding token for roles that cannot login until admin approval
    const shouldReturnOnboardingToken =
      user.role === Role.RESTAURANT || user.role === Role.LIVREUR;

    const onboardingToken = shouldReturnOnboardingToken
      ? await this.jwt.signAsync(
          {
            sub: user.id,
            role: user.role,
            status: user.status,
            scope: 'ONBOARDING',
          },
          { expiresIn: '24h' },
        )
      : undefined;

    return {
      user,
      onboardingToken,
      message: 'Registration successful. Please verify your email.',
    };
  }

  async verifyEmail(rawToken: string) {
    if (!rawToken) throw new BadRequestException('Missing token');

    const tokenHash = sha256(rawToken);

    const user = await this.prisma.user.findFirst({
      where: { emailVerificationTokenHash: tokenHash },
    });

    if (!user) throw new BadRequestException('Invalid verification token');
    if (
      !user.emailVerificationExpiresAt ||
      user.emailVerificationExpiresAt < new Date()
    ) {
      throw new BadRequestException('Verification token expired');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerifiedAt: new Date(),
        emailVerificationTokenHash: null,
        emailVerificationExpiresAt: null,
      },
    });

    return { ok: true };
  }

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase();

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    if (!user.emailVerifiedAt) {
      throw new ForbiddenException({ code: 'EMAIL_NOT_VERIFIED' });
    }

    if (user.role === Role.CLIENT && user.suspendedAt) {
      throw new ForbiddenException({
        code: 'ACCOUNT_SUSPENDED',
        reason: user.statusReason ?? 'suspended',
        suspendedAt: user.suspendedAt,
      });
    }

    if (
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      user.status !== AccountStatus.APPROVED
    ) {
      throw new ForbiddenException({
        code: 'ACCOUNT_NOT_APPROVED',
        status: user.status,
        reason: user.statusReason ?? null,
      });
    }

    // Block login for pending / rejected / changes-required accounts
    if (user.status !== AccountStatus.APPROVED) {
      throw new ForbiddenException({
        code: 'ACCOUNT_NOT_APPROVED',
        status: user.status,
      });
    }

    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      status: user.status,
      scope: 'ACCESS',
    });

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        status: user.status,
      },
    };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        emailVerifiedAt: true,
        clientProfile: {
          select: {
            fullName: true,
            phone: true,
            defaultAddress: true,
            cuisinePreferences: true,
            dietaryRestrictions: true,
          },
        },
        restaurantProfile: {
          select: {
            restaurantName: true,
            establishmentType: true,
            phone: true,
            address: true,
            city: true,
            logoUrl: true,
            coverImageUrl: true,

            legalEntityName: true,
            registrationNumberRNE: true,
            ownershipType: true,
            businessRegistrationDocumentUrl: true,
            hygieneCertificateUrl: true,
            proofOfOwnershipOrLeaseUrl: true,

            payoutMethod: true,
            payoutDetails: true,

            identityCompletedAt: true,
            legalCompletedAt: true,
            payoutCompletedAt: true,
            submittedAt: true,
          },
        },
      },
    });

    if (!user) return null;

    const p = user.clientProfile;
    const isProfileComplete =
      user.role !== Role.CLIENT
        ? true
        : !!p?.fullName &&
          !!p?.phone &&
          !!p?.defaultAddress &&
          (p?.cuisinePreferences?.length ?? 0) > 0 &&
          (p?.dietaryRestrictions?.length ?? 0) > 0;

    return {
      ...user,
      isProfileComplete,
    };
  }
}
