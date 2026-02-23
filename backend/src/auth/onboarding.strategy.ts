import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

export type OnboardingJwtPayload = {
  sub: string;
  role: string;
  status: string;
  scope: 'ONBOARDING' | 'ACCESS';
};

@Injectable()
export class OnboardingJwtStrategy extends PassportStrategy(
  Strategy,
  'onboarding-jwt',
) {
  constructor() {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      // Fail fast on boot instead of silently running with undefined secret
      throw new Error('Missing JWT_SECRET env var');
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: secret,
    });
  }

  validate(payload: OnboardingJwtPayload) {
    if (!payload?.sub) throw new UnauthorizedException();
    if (payload.scope !== 'ONBOARDING') {
      throw new UnauthorizedException('Invalid token scope');
    }
    return payload;
  }
}
