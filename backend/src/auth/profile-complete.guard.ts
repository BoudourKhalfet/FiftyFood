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

    // If there's no authenticated user attached, don't block here.
    // (JwtAuthGuard or route-level guards decide auth.)
    if (!req.user) return true;

    // Only enforce for CLIENT role for now
    if (req.user.role !== Role.CLIENT) return true;

    // Allowlist: routes that must work even if profile incomplete
    const method = req.method.toUpperCase();
    const path: string = (req as any).route?.path
      ? // e.g. "/me" when inside controller "auth"
        `${req.baseUrl}${(req as any).route.path}`
      : req.originalUrl.split('?')[0];

    const allowed = new Set<string>([
      // Auth routes
      'GET /auth/me',

      // Complete profile route
      'PATCH /users/me/complete-profile',
    ]);

    if (allowed.has(`${method} ${path}`)) return true;

    // Check profile completeness from DB
    const user = await this.prisma.user.findUnique({
      where: { id: req.user.sub },
      select: {
        fullName: true,
        phone: true,
        defaultAddress: true,
        cuisinePreferences: true,
        dietaryRestrictions: true,
      },
    });

    // If user not found, let other parts handle it (or treat as forbidden)
    if (!user) return true;

    const complete =
      !!user.fullName &&
      !!user.phone &&
      !!user.defaultAddress &&
      user.cuisinePreferences.length > 0 &&
      user.dietaryRestrictions.length > 0;

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
