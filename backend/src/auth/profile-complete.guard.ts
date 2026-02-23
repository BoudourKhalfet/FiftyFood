/* eslint-disable @typescript-eslint/no-unsafe-member-access */
import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from './jwt.strategy';
import { Role } from '@prisma/client';

type RequestWithUser = Request & { user?: JwtPayload };

@Injectable()
export class ProfileCompleteGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<RequestWithUser>();

    if (!req.user) return true;
    if (req.user.role !== Role.CLIENT) return true;

    const method = req.method.toUpperCase();
    const path: string = (req as any).route?.path
      ? `${req.baseUrl}${(req as any).route.path}`
      : req.originalUrl.split('?')[0];

    const allowed = new Set<string>([
      'GET /auth/me',
      'PATCH /users/me/complete-profile',
      'PATCH /restaurant/onboarding/identity',
      'PATCH /restaurant/onboarding/legal',
      'PATCH /restaurant/onboarding/payout',
      'POST /restaurant/onboarding/submit',
    ]);

    if (allowed.has(`${method} ${path}`)) return true;

    const user = await this.prisma.user.findUnique({
      where: { id: req.user.sub },
      select: {
        clientProfile: {
          select: {
            fullName: true,
            phone: true,
            defaultAddress: true,
            cuisinePreferences: true,
            dietaryRestrictions: true,
          },
        },
      },
    });

    if (!user) return true;

    const p = user.clientProfile;
    const complete =
      !!p?.fullName &&
      !!p?.phone &&
      !!p?.defaultAddress &&
      (p?.cuisinePreferences?.length ?? 0) > 0 &&
      (p?.dietaryRestrictions?.length ?? 0) > 0;

    if (!complete) {
      throw new ForbiddenException({
        code: 'PROFILE_INCOMPLETE',
        message:
          'Client must complete profile step 2 before accessing this resource.',
        required: [
          'fullName',
          'phone',
          'defaultAddress',
          'cuisinePreferences (min 1)',
          'dietaryRestrictions (min 1)',
        ],
      });
    }

    return true;
  }
}
