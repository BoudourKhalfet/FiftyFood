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

    // Update client profile
    const profile = await this.prisma.clientProfile.update({
      where: { userId },
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        defaultAddress: dto.defaultAddress,
        cuisinePreferences: dto.cuisinePreferences,
        dietaryRestrictions: dto.dietaryRestrictions,
      },
      select: {
        fullName: true,
        phone: true,
        defaultAddress: true,
        cuisinePreferences: true,
        dietaryRestrictions: true,
        updatedAt: true,
      },
    });

    // Return user with profile
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

    return { ...user, clientProfile: profile };
  }

  // 1️⃣ Get current user profile and preferences
  async getMe(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        clientProfile: true,
      },
    });
  }

  // 2️⃣ Update personal information
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    return this.prisma.clientProfile.update({
      where: { userId },
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        defaultAddress: dto.defaultAddress,
      },
    });
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
