import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

type RequestWithUser = Request & { user: { sub: string } };

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('me')
  async listMine(
    @Req() req: RequestWithUser,
    @Query('unreadOnly') unreadOnly?: string,
    @Query('limit') limit?: string,
  ) {
    return this.notifications.listForUser(req.user.sub, {
      unreadOnly: unreadOnly === 'true',
      limit: Number(limit) || 50,
    });
  }

  @Get('me/unread-count')
  async unreadCount(@Req() req: RequestWithUser) {
    const count = await this.notifications.unreadCount(req.user.sub);
    return { count };
  }

  @Post('me/device-tokens')
  async registerDeviceToken(
    @Req() req: RequestWithUser,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return this.notifications.registerDeviceToken(req.user.sub, dto);
  }

  @Delete('me/device-tokens')
  async revokeDeviceToken(
    @Req() req: RequestWithUser,
    @Query('token') token: string,
  ) {
    return this.notifications.revokeDeviceToken(req.user.sub, token);
  }

  @Patch(':id/read')
  async markRead(@Req() req: RequestWithUser, @Param('id') id: string) {
    return this.notifications.markRead(req.user.sub, id);
  }

  @Patch('me/read-all')
  async markAllRead(@Req() req: RequestWithUser) {
    return this.notifications.markAllRead(req.user.sub);
  }
}
