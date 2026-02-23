import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdminService } from './admin.service';
import { DecisionDto } from './dto/decision.dto';

@Controller('admin')
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

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
}
