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
import { MailService } from '../mail/mail.service';
import { User } from '@prisma/client';

function sha256(input: string) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

const PASSWORD_REGEX =
  /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mailService: MailService,
  ) {}

  // Helper to generate and save new verification token for user
  private async generateEmailVerificationToken(user: Pick<User, 'id'>) {
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerificationTokenHash: tokenHash,
        emailVerificationExpiresAt: expires,
      },
    });
    return rawToken;
  }

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
        clientProfile:
          dto.role === Role.CLIENT
            ? { create: { termsAcceptedAt: new Date() } }
            : undefined,
        restaurantProfile:
          dto.role === Role.RESTAURANT ? { create: {} } : undefined,
        livreurProfile: dto.role === Role.LIVREUR ? { create: {} } : undefined,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        emailVerifiedAt: true,
      },
    });

    const baseUrl = process.env.PUBLIC_BACKEND_URL || 'http://192.168.43.154:3000';
    const verifyUrl = `${baseUrl}/auth/verify-email?token=${rawToken}`;

    console.log(`[DEV] Verify email for ${user.email}: ${verifyUrl}`);

    // (Optional) Send actual email at registration
    try {
      await this.mailService.sendMail(
        user.email,
        'Verify your email for FiftyFood',
        `<h2>Welcome to FiftyFood!</h2>
         <p>Please <a href="${verifyUrl}">click here to verify your email</a>.</p>
         <p>If you did not request this, you can ignore this email.</p>`,
      );
    } catch (error) {
      console.error('Failed to send verification email:', error);
      // Don't throw - registration succeeds even if email fails
    }

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

    return user;
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
      (user.status === AccountStatus.PENDING || !user.emailVerifiedAt)
    ) {
      const onboardingToken = await this.jwt.signAsync({
        sub: user.id,
        role: user.role,
        status: user.status,
        scope: 'ONBOARDING',
      });
      return {
        onboardingToken,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
        },
        message: user.emailVerifiedAt
          ? 'Your account needs admin approval to start deliveries.'
          : 'Please verify your email and finish onboarding.',
      };
    }

    if (
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      (user.status !== AccountStatus.APPROVED || !user.emailVerifiedAt)
    ) {
      throw new ForbiddenException({
        code: 'ACCOUNT_NOT_APPROVED',
        status: user.status,
        reason: user.statusReason ?? null,
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

  async requestPasswordReset(email: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return;

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    const expires = new Date(Date.now() + 60 * 60 * 1000);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetTokenHash: tokenHash,
        passwordResetTokenExpiresAt: expires,
      },
    });

    const resetUrl =
      (process.env.PASSWORD_RESET_URL ||
        'http://localhost:52530/#/reset-password') + `?token=${rawToken}`;
    try {
      await this.mailService.sendMail(
        user.email,
        'Reset your FiftyFood password',
        `<p>Hello,<br>To reset your password, <a href="${resetUrl}">click here</a>. This link is valid for 1 hour.<br>If you didn't request a reset, ignore this email.</p>`,
      );
    } catch (error) {
      console.error('Failed to send password reset email:', error);
      // Don't throw - allow password reset request to succeed even if email fails
    }
  }

  async resetPassword(token: string, newPassword: string) {
    const tokenHash = sha256(token);

    const user = await this.prisma.user.findFirst({
      where: {
        passwordResetTokenHash: tokenHash,
        passwordResetTokenExpiresAt: { gt: new Date() },
      },
    });

    if (!user) throw new BadRequestException('Invalid or expired reset token');

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetTokenHash: null,
        passwordResetTokenExpiresAt: null,
      },
    });

    return { message: 'Password reset successful' };
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

  async resendVerificationEmail(email: string) {
    const user = await this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });
    if (!user) return;
    if (user.emailVerifiedAt) throw new ForbiddenException('Already verified');
    const token = await this.generateEmailVerificationToken(user);
    const baseUrl = process.env.PUBLIC_BACKEND_URL || 'http://192.168.43.154:3000';
    const verifyUrl = `${baseUrl}/auth/verify-email?token=${token}`;
    try {
      await this.mailService.sendMail(
        user.email,
        'Verify your email for FiftyFood',
        `
          <h2>Welcome to FiftyFood!</h2>
          <p>Please <a href="${verifyUrl}">click here to verify your email</a>.</p>
          <p>If you did not request this, you can ignore this email.</p>
        `,
      );
    } catch (error) {
      console.error('Failed to send verification email:', error);
      // Don't throw - allow resend to succeed even if email fails
    }
  }

  async changePassword(
    userId: string,
    oldPassword: string,
    newPassword: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('User not found');

    const ok = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!ok) throw new BadRequestException('Current password is incorrect');

    if (!PASSWORD_REGEX.test(newPassword)) {
      throw new BadRequestException(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      );
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
    return { message: 'Password changed successfully' };
  }
}
