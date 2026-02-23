import { BadRequestException, Injectable } from '@nestjs/common';
import { DietaryRestriction } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CompleteProfileDto } from './dto/complete-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async completeProfile(userId: string, dto: CompleteProfileDto) {
    const hasNoRestrictions = dto.dietaryRestrictions.includes(
      DietaryRestriction.NO_RESTRICTIONS,
    );
    if (hasNoRestrictions && dto.dietaryRestrictions.length > 1) {
      throw new BadRequestException(
        'If NO_RESTRICTIONS is selected, it must be the only dietary restriction.',
      );
    }

    // Because we create an empty ClientProfile at CLIENT registration,
    // we can safely update it here.
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

    // Return a shape similar to what you returned before
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
}
