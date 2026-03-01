import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Delete,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdminService } from './admin.service';
import { DecisionDto } from './dto/decision.dto';

@Controller('admin')
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('users')
  listAll(@Query('role') role?: 'RESTAURANT' | 'LIVREUR') {
    return this.admin.listAll(role);
  }

  @Get('users/pending')
  listPending(@Query('role') role?: 'RESTAURANT' | 'LIVREUR') {
    return this.admin.listPending(role);
  }

  @Post('users/:id/approve')
  approve(@Param('id') id: string) {
    return this.admin.approveUser(id);
  }

  @Post('users/:id/reject')
  reject(@Param('id') id: string, @Body() dto: DecisionDto) {
    return this.admin.rejectUser(id, dto.reason);
  }

  @Post('users/:id/require-changes')
  requireChanges(@Param('id') id: string, @Body() dto: DecisionDto) {
    return this.admin.requireChanges(id, dto.reason);
  }

  @Post('clients/:id/suspend')
  suspendClient(@Param('id') id: string, @Body() dto: DecisionDto) {
    return this.admin.suspendClient(id, dto.reason);
  }

  @Post('clients/:id/unsuspend')
  unsuspendClient(@Param('id') id: string) {
    return this.admin.unsuspendClient(id);
  }

  @Post('restaurants/:id/suspend')
  suspendRestaurant(@Param('id') id: string, @Body() dto: DecisionDto) {
    return this.admin.suspendRestaurant(id, dto.reason);
  }

  @Post('restaurants/:id/unsuspend')
  unsuspendRestaurant(@Param('id') id: string) {
    return this.admin.unsuspendRestaurant(id);
  }

  @Post('livreurs/:id/suspend')
  suspendLivreur(@Param('id') id: string, @Body() dto: DecisionDto) {
    return this.admin.suspendLivreur(id, dto.reason);
  }

  @Post('livreurs/:id/unsuspend')
  unsuspendLivreur(@Param('id') id: string) {
    return this.admin.unsuspendLivreur(id);
  }

  @Get('users/:id/history')
  async getAccountHistory(@Param('id') id: string) {
    return this.admin.getAccountHistoryForUser(id);
  }

  @Delete('users/:id')
  async deleteUser(@Param('id') id: string) {
    return this.admin.deleteUser(id);
  }
}
