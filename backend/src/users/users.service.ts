/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { CuisinePreference } from '@prisma/client';
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
    console.log('[UsersService] Starting completeProfile for User ID:', userId);
    console.log('[UsersService] Received DTO:', dto);

    try {
      // Update client profile and set submittedAt
      console.log('[UsersService] Updating clientProfile in DB...');
      const profile = await this.prisma.clientProfile.update({
        where: { userId },
        data: {
          fullName: dto.fullName,
          phone: dto.phone,
          defaultAddress: dto.defaultAddress,
          cuisinePreferences: dto.cuisinePreferences,
          submittedAt: new Date(),
          // Do NOT set joinedAt here
        },
        select: {
          fullName: true,
          phone: true,
          defaultAddress: true,
          cuisinePreferences: true,
          submittedAt: true,
          joinedAt: true,
        },
      });
      console.log(
        '[UsersService] clientProfile updated successfully:',
        profile,
      );

      // Check if email is verified, and if so, set joinedAt if profile is completed
      console.log('[UsersService] Finding user...');
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
      console.log('[UsersService] User found:', user);

      // Set joinedAt ONLY if email is verified and profile is completed
      if (user?.emailVerifiedAt && profile?.submittedAt && !profile?.joinedAt) {
        console.log(
          '[UsersService] Email verified and profile submitted. Setting joinedAt...',
        );
        await this.prisma.clientProfile.update({
          where: { userId },
          data: { joinedAt: new Date() },
        });
        // Optionally, reload profile to get updated joinedAt
        profile.joinedAt = new Date();
        console.log('[UsersService] joinedAt set successfully.');
      }

      const response = { ...user, clientProfile: profile };
      console.log('[UsersService] Returning response:', response);
      return response;
    } catch (error) {
      console.error('[UsersService] Error during completeProfile:', error);
      throw error;
    }
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
            submittedAt: true,
            joinedAt: true,
            notificationPreferences: true,
            locationConsentGiven: true,
            locationConsentGivenAt: true,
            lastLatitude: true,
            lastLongitude: true,
            lastLocationAt: true,
          },
        },
        accountHistory: {
          orderBy: { createdAt: 'desc' },
          take: 50,
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

  // 3️⃣ Update preferences (cuisinePreferences)
  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const updated = await this.prisma.clientProfile.update({
      where: { userId },
      data: {
        cuisinePreferences: dto.cuisinePreferences?.map(
          (c) => c as CuisinePreference,
        ),
      },
    });
    return { message: 'Preferences updated', profile: updated };
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

    await this.prisma.accountHistory.create({
      data: {
        userId,
        action: 'PROFILE_EDIT',
        field: 'password',
        oldValue: null,
        newValue: null,
        actorId: userId,
        actorRole: 'USER',
      },
    });
    return { message: 'Password changed.' };
  }

  // Get all orders for the current client (current + history)

  async getMyOrders(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: { clientId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        restaurant: {
          select: {
            restaurantProfile: { select: { restaurantName: true } },
          },
        },
      },
    });

    // Match fields to UI designs!
    return Promise.all(
      orders.map(async (order) => {
        let mainItem: any;
        try {
          const parsed =
            typeof order.items === 'string'
              ? JSON.parse(order.items)
              : order.items;
          mainItem = Array.isArray(parsed) ? parsed[0] : parsed.main || parsed;
        } catch {
          mainItem = {};
        }

        let offer = null;
        if (mainItem?.offerId) {
          offer = await this.prisma.offer.findUnique({
            where: { id: mainItem.offerId },
            select: {
              description: true,
              pickupTime: true,
              discountedPrice: true,
              photoUrl: true,
              visibility: true, // <-- Ensure this is fetched!
            },
          });
        }

        return {
          id: order.id,
          status: order.status,
          collectionMethod: order.collectionMethod,
          mealName: offer?.description ?? mainItem?.name ?? '',
          restaurantName:
            offer?.visibility === 'ANONYMOUS'
              ? 'Anonymous'
              : (order.restaurant?.restaurantProfile?.restaurantName ?? ''),

          timeSlot: offer?.pickupTime ?? mainItem?.pickupTime ?? '',
          date: order.createdAt.toISOString().substring(0, 10),
          price: offer?.discountedPrice ?? order.total ?? 0,
          reference: order.reference,
          imageUrl: offer?.photoUrl ?? '',
          delivered: order.status === 'DELIVERED',
          qr: order.status === 'READY',
        };
      }),
    );
  }

  async deleteAccount(userId: string): Promise<{ message: string }> {
    // If you want a soft-delete:
    await this.prisma.user.update({
      where: { id: userId },
      data: { status: 'SUSPENDED' }, // or any other 'deleted'/'inactive' status
    });
    return { message: 'Account deleted.' };

    // For a hard delete:
    // await this.prisma.user.delete({ where: { id: userId } });
    // return { message: 'Account deleted.' };
  }

  async setClientLocationConsent(userId: string, consented: boolean) {
    const profile = await this.prisma.clientProfile.findUnique({
      where: { userId },
    });
    if (!profile) throw new NotFoundException('Client profile not found');
    return this.prisma.clientProfile.update({
      where: { userId },
      data: {
        locationConsentGiven: consented,
        locationConsentGivenAt: new Date(),
      },
    });
  }

  async updateClientLocation(
    userId: string,
    latitude: number,
    longitude: number,
  ) {
    const profile = await this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { id: true, locationConsentGiven: true },
    });

    if (!profile) throw new NotFoundException('Client profile not found');
    if (!profile.locationConsentGiven) {
      throw new BadRequestException('Location consent is required');
    }

    return this.prisma.clientProfile.update({
      where: { userId },
      data: {
        lastLatitude: latitude,
        lastLongitude: longitude,
        lastLocationAt: new Date(),
      } as any,
    });
  }
}
