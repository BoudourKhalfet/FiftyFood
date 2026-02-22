import { Body, Controller, Patch, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { CompleteProfileDto } from './dto/complete-profile.dto';
import { UsersService } from './users.service';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
type RequestWithUser = Request & { user: JwtPayload };

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CLIENT)
  @Patch('me/complete-profile')
  completeProfile(
    @Req() req: RequestWithUser,
    @Body() dto: CompleteProfileDto,
  ) {
    return this.users.completeProfile(req.user.sub, dto);
  }
}
