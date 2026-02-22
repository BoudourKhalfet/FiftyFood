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

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        defaultAddress: dto.defaultAddress,
        cuisinePreferences: dto.cuisinePreferences,
        dietaryRestrictions: dto.dietaryRestrictions,
      },
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
        updatedAt: true,
      },
    });
  }
}
