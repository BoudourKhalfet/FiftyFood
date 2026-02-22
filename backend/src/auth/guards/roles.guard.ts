import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { JwtPayload } from '../jwt.strategy';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // No @Roles() metadata => no role restriction
    if (!requiredRoles || requiredRoles.length === 0) return true;

    const req = context.switchToHttp().getRequest<{ user?: JwtPayload }>();
    const user = req.user;

    // Should normally be handled by JwtAuthGuard, but keep it explicit
    if (!user) throw new UnauthorizedException();

    const allowed = requiredRoles.includes(user.role);
    if (!allowed) {
      throw new ForbiddenException({
        code: 'ROLE_FORBIDDEN',
        message: `Required roles: ${requiredRoles.join(', ')}`,
      });
    }

    return true;
  }
}
