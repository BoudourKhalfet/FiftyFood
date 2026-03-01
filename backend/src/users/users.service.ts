/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { CuisinePreference, DietaryRestriction } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CompleteProfileDto } from './dto/complete-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateNotificationsDto } from './dto/update-notifications.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  // Complete profile (step 2 for client onboarding)
  async completeProfile(userId: string, dto: CompleteProfileDto) {
    const hasNoRestrictions = dto.dietaryRestrictions.includes(
      DietaryRestriction.NO_RESTRICTIONS,
    );
    if (hasNoRestrictions && dto.dietaryRestrictions.length > 1) {
      throw new BadRequestException(
        'If NO_RESTRICTIONS is selected, it must be the only dietary restriction.',
      );
    }

    // Update client profile and set submittedAt
    const profile = await this.prisma.clientProfile.update({
      where: { userId },
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        defaultAddress: dto.defaultAddress,
        cuisinePreferences: dto.cuisinePreferences,
        dietaryRestrictions: dto.dietaryRestrictions,
        submittedAt: new Date(),
        // Do NOT set joinedAt here
      },
      select: {
        fullName: true,
        phone: true,
        defaultAddress: true,
        cuisinePreferences: true,
        dietaryRestrictions: true,
        submittedAt: true,
        joinedAt: true,
      },
    });

    // Check if email is verified, and if so, set joinedAt if profile is completed
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        emailVerifiedAt: true,
      },
    });

    // Set joinedAt ONLY if email is verified and profile is completed
    if (user?.emailVerifiedAt && profile?.submittedAt && !profile?.joinedAt) {
      await this.prisma.clientProfile.update({
        where: { userId },
        data: { joinedAt: new Date() },
      });
      // Optionally, reload profile to get updated joinedAt
      profile.joinedAt = new Date();
    }

    return { ...user, clientProfile: profile };
  }

  async submitClientProfile(userId: string) {
    // Find clientProfile
    const profile = await this.prisma.clientProfile.findUnique({
      where: { userId },
    });

    // You can validate that required fields are completed here (optional)
    if (!profile?.fullName || !profile?.phone || !profile?.defaultAddress) {
      throw new BadRequestException('Profile is incomplete');
    }

    // Set submittedAt
    await this.prisma.clientProfile.update({
      where: { userId },
      data: { submittedAt: new Date() },
    });

    // Optionally set joinedAt if email is verified
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.emailVerifiedAt) {
      await this.prisma.clientProfile.update({
        where: { userId },
        data: { joinedAt: new Date() },
      });
    }

    return { message: 'Profile submitted successfully.' };
  }

  // 1️⃣ Get current user profile and preferences
  async getMe(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        clientProfile: {
          select: {
            fullName: true,
            phone: true,
            defaultAddress: true,
            cuisinePreferences: true,
            dietaryRestrictions: true,
            submittedAt: true,
            joinedAt: true,
            notificationPreferences: true,
          },
        },
        accountHistory: {
          orderBy: { createdAt: 'desc' },
          take: 50, // or however many you want to show
        },
      },
    });
  }

  // 2️⃣ Update personal information
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // 1. Fetch old profile
    const oldProfile = await this.prisma.clientProfile.findUnique({
      where: { userId },
    });

    // 2. Update profile
    const updatedProfile = await this.prisma.clientProfile.update({
      where: { userId },
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        defaultAddress: dto.defaultAddress,
      },
    });

    // 3. Track changes in accountHistory
    const fieldsToTrack: (keyof UpdateProfileDto)[] = [
      'fullName',
      'phone',
      'defaultAddress',
    ];
    for (const field of fieldsToTrack) {
      if (
        dto[field] !== undefined &&
        dto[field] !== (oldProfile as any)[field]
      ) {
        await this.prisma.accountHistory.create({
          data: {
            userId,
            action: 'PROFILE_EDIT',
            field,
            oldValue: (oldProfile as any)[field],
            newValue: dto[field],
            actorId: userId,
            actorRole: 'USER',
          },
        });
      }
    }

    // 4. Return updated profile as before
    return updatedProfile;
  }

  // 3️⃣ Update preferences (cuisinePreferences, dietaryRestrictions)
  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    return this.prisma.clientProfile.update({
      where: { userId },
      data: {
        cuisinePreferences: dto.cuisinePreferences?.map(
          (c) => c as CuisinePreference,
        ),
        dietaryRestrictions: dto.dietaryRestrictions?.map(
          (d) => d as DietaryRestriction,
        ),
      },
    });
  }

  // 4️⃣ Update notification settings (as plain object)
  async updateNotifications(userId: string, dto: UpdateNotificationsDto) {
    return this.prisma.clientProfile.update({
      where: { userId },
      data: {
        notificationPreferences: { ...dto },
      },
    });
  }

  // 5️⃣ Change password logic
  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');

    const isMatch = await bcrypt.compare(dto.oldPassword, user.passwordHash);
    if (!isMatch) throw new UnauthorizedException('Invalid current password');

    const newHash = await bcrypt.hash(dto.newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });
    return { message: 'Password changed.' };
  }

  // 6️⃣ Get all orders for the current client (current + history)
  async getMyOrders(userId: string) {
    return this.prisma.order.findMany({
      where: { clientId: userId },
      orderBy: [{ createdAt: 'desc' }],
    });
  }
}
