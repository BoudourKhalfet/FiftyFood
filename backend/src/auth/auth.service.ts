import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AccountStatus, ClientType, Prisma, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { JwtService } from '@nestjs/jwt';
import * as admin from 'firebase-admin';
import { MailService } from '../mail/mail.service';
import { User } from '@prisma/client';

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

const PASSWORD_REGEX =
  /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;

function normalizeGoogleRole(role?: string): Role | null {
  const normalizedRole = role?.trim().toUpperCase();
  if (normalizedRole === 'CLIENT') return Role.CLIENT;
  if (normalizedRole === 'DELIVERER' || normalizedRole === 'LIVREUR') {
    return Role.LIVREUR;
  }
  if (normalizedRole === 'RESTAURANT') return Role.RESTAURANT;
  return null;
}

function initializeFirebaseAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    return false;
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }

  return true;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mailService: MailService,
  ) {}

  private decryptWelcomePayload(token: string): {
    email: string;
    password: string;
    roleLabel?: string;
  } {
    const [ivB64, tagB64, dataB64] = token.split('.');
    if (!ivB64 || !tagB64 || !dataB64) {
      throw new BadRequestException('Invalid welcome payload');
    }

    const iv = Buffer.from(ivB64, 'base64url');
    const tag = Buffer.from(tagB64, 'base64url');
    const encrypted = Buffer.from(dataB64, 'base64url');

    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      getEmailPayloadKey(),
      iv,
    );
    decipher.setAuthTag(tag);

    const decrypted = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]).toString('utf8');

    const parsed = JSON.parse(decrypted) as {
      email: string;
      password: string;
      roleLabel?: string;
    };

    if (!parsed.email || !parsed.password) {
      throw new BadRequestException('Invalid welcome payload');
    }

    return parsed;
  }

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

  private async generateEmailChangeToken(user: Pick<User, 'id'>) {
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        emailChangeTokenHash: tokenHash,
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

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(dto.email)) {
      throw new BadRequestException('Please enter a valid email address');
    }

    // Validate password length
    if (!dto.password || dto.password.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }

    const email = dto.email.toLowerCase();

    try {
      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing)
        throw new BadRequestException(
          'This email is already registered. Please use a different email or sign in.',
        );
    } catch (e: unknown) {
      if (e instanceof BadRequestException) {
        throw e;
      }
      console.error('Database error checking email:', e);
      throw new BadRequestException(
        'Failed to check email availability. Please try again.',
      );
    }

    let passwordHash: string;
    try {
      passwordHash = await bcrypt.hash(dto.password, 10);
    } catch (e) {
      console.error('Password hashing error:', e);
      throw new BadRequestException('Registration error. Please try again.');
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = sha256(rawToken);
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const status =
      dto.role === Role.CLIENT ? AccountStatus.APPROVED : AccountStatus.PENDING;

    // Build data object conditionally to avoid unsafe assignment
    const createDataBase = {
      email,
      passwordHash,
      role: dto.role,
      status,
      emailVerifiedAt: null,
      emailVerificationTokenHash: tokenHash,
      emailVerificationExpiresAt: expires,
    };

    const createData =
      dto.role === Role.CLIENT
        ? {
            ...createDataBase,
            clientProfile: {
              create: {
                termsAcceptedAt: new Date(),
                clientType: dto.clientType ?? 'NORMAL',
                societyName: dto.societyName,
                fiscalNumber: dto.fiscalNumber,
                proPhone: dto.proPhone,
                proAddress: dto.proAddress,
              },
            },
          }
        : dto.role === Role.RESTAURANT
          ? { ...createDataBase, restaurantProfile: { create: {} } }
          : { ...createDataBase, livreurProfile: { create: {} } };

    let user;
    try {
      user = await this.prisma.user.create({
        data: createData,
        select: {
          id: true,
          email: true,
          role: true,
          status: true,
          emailVerifiedAt: true,
        },
      });
    } catch (e: unknown) {
      console.error('User creation error:', e);
      const err = e as Error & { code?: string };
      if (err.code === 'P2002') {
        throw new BadRequestException(
          'This email is already registered. Please use a different email or sign in.',
        );
      }
      throw new BadRequestException('Registration failed. Please try again.');
    }

    const baseUrl =
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.100.6:3000';
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

  async verifyEmail(
    rawToken: string,
    welcomeToken?: string,
    isEmailChange = false,
  ) {
    if (!rawToken) throw new BadRequestException('Missing token');

    const tokenHash = sha256(rawToken);

    const user = await this.prisma.user.findFirst({
      where: isEmailChange
        ? { emailChangeTokenHash: tokenHash }
        : { emailVerificationTokenHash: tokenHash },
    });

    if (!user) throw new BadRequestException('Invalid verification token');

    if (isEmailChange) {
      const changeUser = user as typeof user & {
        emailChangeExpiresAt?: Date | null;
        emailChangeTokenHash?: string | null;
        pendingEmail?: string | null;
      };

      if (
        !changeUser.emailChangeExpiresAt ||
        changeUser.emailChangeExpiresAt < new Date()
      ) {
        throw new BadRequestException('Verification token expired');
      }

      if (!changeUser.pendingEmail) {
        throw new BadRequestException('Missing pending email');
      }

      const verifiedUser = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          email: changeUser.pendingEmail.toLowerCase(),
          pendingEmail: null,
          emailChangeTokenHash: null,

          emailVerifiedAt: new Date(),
        },
      });

      return verifiedUser;
    }

    if (
      !user.emailVerificationExpiresAt ||
      user.emailVerificationExpiresAt < new Date()
    ) {
      throw new BadRequestException('Verification token expired');
    }

    const verifiedUser = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerifiedAt: new Date(),
        emailVerificationTokenHash: null,
        emailVerificationExpiresAt: null,
      },
    });

    if (welcomeToken) {
      try {
        const payload = this.decryptWelcomePayload(welcomeToken);

        if (payload.email.toLowerCase() === verifiedUser.email.toLowerCase()) {
          await this.mailService.sendMail(
            verifiedUser.email,
            'Welcome to FiftyFood - Your sign-in credentials',
            `<h2>Welcome to FiftyFood!</h2>
             <p>Your email is now verified and your account is active.</p>
             <p>Email: <strong>${payload.email}</strong></p>
             <p>Temporary password: <strong>${payload.password}</strong></p>
             <p>You can now sign in to the application.</p>
             <p>For security, please change your password later from your account settings.</p>`,
          );
        }
      } catch (error) {
        console.error(
          'Failed to send post-verification credentials email:',
          error,
        );
      }
    }

    return verifiedUser;
  }

  async requestEmailChange(userId: string, newEmail: string) {
    const email = newEmail.trim().toLowerCase();
    if (!email) {
      throw new BadRequestException('Email is required');
    }

    const currentUser = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, role: true },
    });
    if (!currentUser) throw new UnauthorizedException('User not found');
    if (
      currentUser.role !== Role.RESTAURANT &&
      currentUser.role !== Role.CLIENT &&
      currentUser.role !== Role.LIVREUR
    ) {
      throw new ForbiddenException(
        'Only client, deliverer, or restaurant accounts can use this flow',
      );
    }
    if (currentUser.email.toLowerCase() === email) {
      throw new BadRequestException('New email must be different');
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing && existing.id !== userId) {
      throw new BadRequestException('Email already in use');
    }

    const rawToken = await this.generateEmailChangeToken({ id: userId });
    await this.prisma.user.update({
      where: { id: userId },
      data: { pendingEmail: email },
    });

    const baseUrl =
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.100.6:3000';
    const verifyUrl = `${baseUrl}/auth/verify-email?token=${rawToken}&changeEmail=1`;

    try {
      await this.mailService.sendMail(
        email,
        'Verify your new FiftyFood email',
        `<h2>Verify your new email</h2>
         <p>We received a request to change your FiftyFood email address.</p>
         <p>Please <a href="${verifyUrl}">click here to verify your new email</a>.</p>
         <p>If you did not request this change, you can ignore this email.</p>`,
      );
    } catch (error) {
      console.error('Failed to send email change verification:', error);
    }

    return { message: 'Verification email sent to your new address.' };
  }

  private isClientProfileComplete(user: {
    clientProfile?: {
      clientType?: string | null;
      fullName?: string | null;
      phone?: string | null;
      defaultAddress?: string | null;
      cuisinePreferences?: unknown[] | null;
      societyName?: string | null;
      fiscalNumber?: string | null;
      proPhone?: string | null;
    } | null;
  }) {
    const profile = user.clientProfile;
    const isPro = profile?.clientType === 'PRO';
    if (isPro) {
      return (
        !!profile?.societyName &&
        !!profile?.fiscalNumber &&
        !!profile?.proPhone &&
        (profile?.cuisinePreferences?.length ?? 0) > 0
      );
    }
    return (
      !!profile?.fullName &&
      !!profile?.phone &&
      !!profile?.defaultAddress &&
      (profile?.cuisinePreferences?.length ?? 0) > 0
    );
  }

  private isRestaurantProfileComplete(user: {
    restaurantProfile?: {
      restaurantName?: string | null;
      establishmentType?: string | null;
      phone?: string | null;
      address?: string | null;
      city?: string | null;
      legalEntityName?: string | null;
      registrationNumberRNE?: string | null;
      ownershipType?: string | null;
      businessRegistrationDocumentUrl?: string | null;
      hygieneCertificateUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
  }) {
    return this.getRestaurantNextOnboardingStep(user) == null;
  }

  private isDelivererProfileComplete(user: {
    livreurProfile?: {
      fullName?: string | null;
      phone?: string | null;
      vehicleType?: string | null;
      zone?: string | null;
      cinOrPassportNumber?: string | null;
      licensePhotoUrl?: string | null;
      vehicleOwnershipDocUrl?: string | null;
      vehiclePhotoUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
  }) {
    return this.getDelivererNextOnboardingStep(user) == null;
  }

  private getClientNextOnboardingStep(user: {
    clientProfile?: {
      clientType?: string | null;
      fullName?: string | null;
      phone?: string | null;
      defaultAddress?: string | null;
      cuisinePreferences?: unknown[] | null;
      societyName?: string | null;
      fiscalNumber?: string | null;
      proPhone?: string | null;
    } | null;
  }): number | null {
    return this.isClientProfileComplete(user) ? null : 2;
  }

  private getRestaurantNextOnboardingStep(user: {
    restaurantProfile?: {
      restaurantName?: string | null;
      establishmentType?: string | null;
      phone?: string | null;
      address?: string | null;
      city?: string | null;
      legalEntityName?: string | null;
      registrationNumberRNE?: string | null;
      ownershipType?: string | null;
      businessRegistrationDocumentUrl?: string | null;
      hygieneCertificateUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
  }): number | null {
    const p = user.restaurantProfile;
    if (!p) return 2;

    const identityComplete =
      !!p.restaurantName &&
      !!p.establishmentType &&
      !!p.phone &&
      !!p.address &&
      !!p.city;
    if (!identityComplete) return 2;

    const legalComplete =
      !!p.legalEntityName &&
      !!p.registrationNumberRNE &&
      !!p.ownershipType &&
      !!p.businessRegistrationDocumentUrl &&
      !!p.hygieneCertificateUrl &&
      !!p.termsAcceptedAt;
    if (!legalComplete) return 3;

    if (!p.submittedAt) return 4;
    return null;
  }

  private getDelivererNextOnboardingStep(user: {
    livreurProfile?: {
      fullName?: string | null;
      phone?: string | null;
      vehicleType?: string | null;
      zone?: string | null;
      cinOrPassportNumber?: string | null;
      licensePhotoUrl?: string | null;
      vehicleOwnershipDocUrl?: string | null;
      vehiclePhotoUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
  }): number | null {
    const p = user.livreurProfile;
    if (!p) return 2;

    const identityComplete =
      !!p.fullName && !!p.phone && !!p.vehicleType && !!p.zone;
    if (!identityComplete) return 2;

    const needsLicense =
      p.vehicleType?.toUpperCase() == 'CAR' ||
      p.vehicleType?.toUpperCase() == 'MOTORCYCLE';
    const legalComplete =
      !!p.cinOrPassportNumber &&
      !!p.vehicleOwnershipDocUrl &&
      !!p.termsAcceptedAt &&
      (!needsLicense || !!p.licensePhotoUrl);
    if (!legalComplete) return 3;

    if (!p.submittedAt) return 4;
    return null;
  }

  private getNextOnboardingStep(user: {
    role: Role;
    clientProfile?: {
      clientType?: string | null;
      fullName?: string | null;
      phone?: string | null;
      defaultAddress?: string | null;
      cuisinePreferences?: unknown[] | null;
      societyName?: string | null;
      fiscalNumber?: string | null;
      proPhone?: string | null;
    } | null;
    restaurantProfile?: {
      restaurantName?: string | null;
      establishmentType?: string | null;
      phone?: string | null;
      address?: string | null;
      city?: string | null;
      legalEntityName?: string | null;
      registrationNumberRNE?: string | null;
      ownershipType?: string | null;
      businessRegistrationDocumentUrl?: string | null;
      hygieneCertificateUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
    livreurProfile?: {
      fullName?: string | null;
      phone?: string | null;
      vehicleType?: string | null;
      zone?: string | null;
      cinOrPassportNumber?: string | null;
      licensePhotoUrl?: string | null;
      vehicleOwnershipDocUrl?: string | null;
      vehiclePhotoUrl?: string | null;
      termsAcceptedAt?: Date | null;
      submittedAt?: Date | null;
    } | null;
  }): number | null {
    if (user.role === Role.CLIENT)
      return this.getClientNextOnboardingStep(user);
    if (user.role === Role.RESTAURANT)
      return this.getRestaurantNextOnboardingStep(user);
    if (user.role === Role.LIVREUR)
      return this.getDelivererNextOnboardingStep(user);
    return null;
  }

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase();

    const user = await this.prisma.user.findUnique({
      where: { email },
      include: {
        clientProfile: true,
        restaurantProfile: true,
        livreurProfile: true,
      },
    });
    if (!user) throw new UnauthorizedException('Account does not exist');

    if (user.status === AccountStatus.SUSPENDED || user.suspendedAt) {
      throw new ForbiddenException({
        code: 'ACCOUNT_SUSPENDED',
        reason: user.statusReason ?? 'suspended',
        suspendedAt: user.suspendedAt,
      });
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    if (!user.emailVerifiedAt) {
      throw new ForbiddenException({ code: 'EMAIL_NOT_VERIFIED' });
    }

    const rawNextOnboardingStep = this.getNextOnboardingStep(user);
    const nextOnboardingStep =
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      user.status === AccountStatus.APPROVED &&
      rawNextOnboardingStep === 4
        ? null
        : rawNextOnboardingStep;
    const needsOnboarding = nextOnboardingStep != null;

    if (needsOnboarding) {
      const onboardingToken = await this.jwt.signAsync({
        sub: user.id,
        role: user.role,
        status: user.status,
        scope: 'ONBOARDING',
      });

      return {
        onboardingToken,
        requiresOnboarding: true,
        nextOnboardingStep,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
          clientProfile: user.clientProfile
            ? { clientType: user.clientProfile.clientType }
            : null,
        },
        message:
          user.role === Role.CLIENT
            ? 'Please complete your profile to access the app.'
            : 'Please complete your onboarding profile to access the app.',
      };
    }

    if (
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      user.status === AccountStatus.PENDING
    ) {
      const onboardingToken = await this.jwt.signAsync({
        sub: user.id,
        role: user.role,
        status: user.status,
        scope: 'ONBOARDING',
      });
      return {
        onboardingToken,
        requiresOnboarding: false,
        pendingApproval: true,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
        },
        message: user.emailVerifiedAt
          ? 'Your account needs admin approval to start using the app.'
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

  // Sign in / register using Google ID token
  async signInWithGoogle(idToken: string, requestedRole?: string) {
    if (!initializeFirebaseAdmin()) {
      throw new BadRequestException('Firebase admin is not configured');
    }

    const role = normalizeGoogleRole(requestedRole);
    if (!role) {
      throw new BadRequestException('Google sign-in role is required');
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (e: unknown) {
      console.error(
        'Google sign-in verification failed',
        e instanceof Error ? e.message : String(e),
      );
      throw new BadRequestException('Invalid Google ID token');
    }

    const email = String(decodedToken.email || '').toLowerCase();
    const emailVerified = decodedToken.email_verified === true;

    if (!email || !emailVerified) {
      throw new BadRequestException('Google account email not verified');
    }

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
      include: {
        clientProfile: true,
        restaurantProfile: true,
        livreurProfile: true,
      },
    });

    let user = existingUser;

    if (user) {
      if (user.role !== role) {
        throw new ForbiddenException({
          code: 'ROLE_MISMATCH',
          expectedRole: role,
          actualRole: user.role,
        });
      }

      if (!user.emailVerifiedAt) {
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { emailVerifiedAt: new Date() },
          include: {
            clientProfile: true,
            restaurantProfile: true,
            livreurProfile: true,
          },
        });
      }
    } else {
      const baseData = {
        email,
        passwordHash: await bcrypt.hash(
          crypto.randomBytes(16).toString('hex'),
          10,
        ),
        role,
        emailVerifiedAt: new Date(),
      };

      const createData: Prisma.UserCreateInput =
        role === Role.CLIENT
          ? {
              ...baseData,
              status: AccountStatus.APPROVED,
              clientProfile: {
                create: {
                  termsAcceptedAt: new Date(),
                  clientType: ClientType.NORMAL,
                },
              },
            }
          : role === Role.RESTAURANT
            ? {
                ...baseData,
                status: AccountStatus.PENDING,
                restaurantProfile: {
                  create: {},
                },
              }
            : {
                ...baseData,
                status: AccountStatus.PENDING,
                livreurProfile: {
                  create: {},
                },
              };

      user = await this.prisma.user.create({
        data: createData,
        include: {
          clientProfile: true,
          restaurantProfile: true,
          livreurProfile: true,
        },
      });
    }

    if (!user) {
      throw new BadRequestException('Unable to complete Google sign-in');
    }

    if (user.status === AccountStatus.SUSPENDED || user.suspendedAt) {
      throw new ForbiddenException({ code: 'ACCOUNT_SUSPENDED' });
    }

    const rawNextOnboardingStep = this.getNextOnboardingStep(user);
    const nextOnboardingStep =
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      user.status === AccountStatus.APPROVED &&
      rawNextOnboardingStep === 4
        ? null
        : rawNextOnboardingStep;

    const needsOnboarding = nextOnboardingStep != null;

    if (needsOnboarding) {
      const onboardingToken = await this.jwt.signAsync({
        sub: user.id,
        role: user.role,
        status: user.status,
        scope: 'ONBOARDING',
      });

      return {
        onboardingToken,
        requiresOnboarding: true,
        nextOnboardingStep,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
          clientProfile: user.clientProfile
            ? { clientType: user.clientProfile.clientType }
            : null,
        },
        message:
          user.role === Role.CLIENT
            ? 'Please complete your profile to access the app.'
            : 'Please complete your onboarding profile to access the app.',
      };
    }

    if (
      (user.role === Role.RESTAURANT || user.role === Role.LIVREUR) &&
      user.status === AccountStatus.PENDING
    ) {
      const onboardingToken = await this.jwt.signAsync({
        sub: user.id,
        role: user.role,
        status: user.status,
        scope: 'ONBOARDING',
      });

      return {
        onboardingToken,
        requiresOnboarding: false,
        pendingApproval: true,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
        },
        message: user.emailVerifiedAt
          ? 'Your account needs admin approval to start using the app.'
          : 'Please verify your email and finish onboarding.',
      };
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
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email: normalizedEmail },
    });
    if (!user) {
      return {
        message:
          'If an account exists for this email, a reset link has been sent.',
      };
    }

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

    const browserResetUrl =
      (process.env.PASSWORD_RESET_URL ||
        'http://192.168.100.6:52530/reset-password') + `?token=${rawToken}`;
    const appResetUrl = `fiftyfood://reset-password?token=${encodeURIComponent(
      rawToken,
    )}`;
    try {
      await this.mailService.sendMail(
        user.email,
        'Reset your FiftyFood password',
        `<p>Hello,</p>
         <p>To reset your password on the web, <a href="${browserResetUrl}">click here</a>.</p>
         <p>To open the reset page in the FiftyFood app, <a href="${appResetUrl}">tap here</a>.</p>
         <p>This link is valid for 1 hour. If you didn't request a reset, ignore this email.</p>`,
      );
    } catch (error) {
      console.error('Failed to send password reset email:', error);
    }

    return {
      message:
        'If an account exists for this email, a reset link has been sent.',
    };
  }

  async resetPassword(token: string, newPassword: string) {
    const tokenHash = sha256(token);

    if (!PASSWORD_REGEX.test(newPassword)) {
      throw new BadRequestException(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      );
    }

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
        pendingEmail: true,
        clientProfile: {
          select: {
            clientType: true,
            fullName: true,
            phone: true,
            defaultAddress: true,
            cuisinePreferences: true,
            societyName: true,
            fiscalNumber: true,
            proPhone: true,
            proAddress: true,
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

    const clientProfile = user.clientProfile;
    const isProClient = clientProfile?.clientType === 'PRO';
    const isProfileComplete =
      user.role !== Role.CLIENT
        ? true
        : isProClient
          ? !!clientProfile?.societyName &&
            !!clientProfile?.fiscalNumber &&
            !!clientProfile?.proPhone &&
            (clientProfile?.cuisinePreferences?.length ?? 0) > 0
          : !!clientProfile?.fullName &&
            !!clientProfile?.phone &&
            !!clientProfile?.defaultAddress &&
            (clientProfile?.cuisinePreferences?.length ?? 0) > 0;

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
    const baseUrl =
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.100.6:3000';
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
