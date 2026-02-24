import {
  Get,
  Post,
  Body,
  Controller,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtPayload } from '../auth/jwt.strategy';
import { CompleteProfileDto } from './dto/complete-profile.dto';
import { UsersService } from './users.service';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateNotificationsDto } from './dto/update-notifications.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
type RequestWithUser = Request & { user: JwtPayload };

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @UseGuards(RolesGuard)
  @Roles(Role.CLIENT)
  @Patch('me/complete-profile')
  completeProfile(
    @Req() req: RequestWithUser,
    @Body() dto: CompleteProfileDto,
  ) {
    return this.users.completeProfile(req.user.sub, dto);
  }
  // 1️⃣ Get my profile (personal info, preferences, notifications)
  @Get('me')
  getMe(@Req() req: RequestWithUser) {
    return this.users.getMe(req.user.sub);
  }

  // 2️⃣ Update personal info (fullName, phone, defaultAddress)
  @Patch('me/profile')
  updateProfile(@Req() req: RequestWithUser, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(req.user.sub, dto);
  }

  // 3️⃣ Update preferences (cuisinePreferences, dietaryRestrictions)
  @Patch('me/preferences')
  updatePreferences(
    @Req() req: RequestWithUser,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.users.updatePreferences(req.user.sub, dto);
  }

  // 4️⃣ Update notification settings
  @Patch('me/notifications')
  updateNotifications(
    @Req() req: RequestWithUser,
    @Body() dto: UpdateNotificationsDto,
  ) {
    return this.users.updateNotifications(req.user.sub, dto);
  }

  // 5️⃣ Change password (for Settings tab)
  @Post('me/change-password')
  changePassword(@Req() req: RequestWithUser, @Body() dto: ChangePasswordDto) {
    return this.users.changePassword(req.user.sub, dto);
  }

  // 6️⃣ Get all my orders (current + past)
  @Get('me/orders')
  getMyOrders(@Req() req: RequestWithUser) {
    return this.users.getMyOrders(req.user.sub);
  }
}
