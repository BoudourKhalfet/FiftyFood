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

    return {
      user,
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
      throw new ForbiddenException('Email not verified');
    }

    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      status: user.status,
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
        fullName: true,
        phone: true,
        defaultAddress: true,
        cuisinePreferences: true,
        dietaryRestrictions: true,
      },
    });

    if (!user) return null;

    const isProfileComplete =
      user.role !== 'CLIENT'
        ? true
        : !!user.fullName &&
          !!user.phone &&
          !!user.defaultAddress &&
          user.cuisinePreferences.length > 0 &&
          user.dietaryRestrictions.length > 0;

    return {
      ...user,
      isProfileComplete,
    };
  }
}
