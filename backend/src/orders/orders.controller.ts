import {
  Controller,
  BadRequestException,
  Post,
  Body,
  Req,
  Get,
  UseGuards,
  NotFoundException,
  Param,
  ForbiddenException,
  Patch,
  Query,
} from '@nestjs/common';
import { Request } from 'express';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderSummary } from './order-summary.interface';
import { AuthGuard } from '@nestjs/passport/dist/auth.guard';
import { Role } from '@prisma/client';

@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  async create(
    @Body() createOrderDto: CreateOrderDto,
    @Req() req: Request,
  ): Promise<{ success: true; order: OrderSummary }> {
    const clientId = (req.user as { id: string }).id; // Type is now string!
    const order = await this.ordersService.create(createOrderDto, clientId);
    return { success: true, order };
  }

  @Get('client')
  @UseGuards(AuthGuard('jwt'))
  async getMyOrders(@Req() req: Request) {
    const clientId = (req.user as { id: string }).id;
    return this.ordersService.findByClient(clientId);
  }

  @UseGuards(AuthGuard('jwt'))
  @Get()
  async getAllOrders(@Req() req: Request) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.ADMIN) {
      throw new ForbiddenException('Only admins can access all orders');
    }
    return this.ordersService.findAllOrders();
  }
  @UseGuards(AuthGuard('jwt'))
  @Get(':orderId/tracking')
  async getOrderTracking(
    @Param('orderId') orderId: string,
    @Req() req: Request,
  ) {
    const user = req.user as { id: string; role: Role };
    const tracking = await this.ordersService.getOrderTracking(orderId, user);
    if (!tracking) throw new NotFoundException('Order not found');
    return tracking;
  }

  @UseGuards(AuthGuard('jwt'))
  @Get('deliverer/available')
  async getAvailableOrdersForDeliverer() {
    return this.ordersService.findAvailableForDeliverer();
  }

  @Get('deliverer/active')
  @UseGuards(AuthGuard('jwt'))
  async getActiveDeliveries(@Req() req: Request) {
    const userId = (req.user as { id: string }).id;
    return this.ordersService.findActiveForDeliverer(userId);
  }

  @UseGuards(AuthGuard('jwt'))
  @Get('deliverer/history')
  async getDelivererHistory(@Req() req: Request) {
    const userId = (req.user as { id: string }).id;
    return this.ordersService.findHistoryForDeliverer(userId);
  }

  @UseGuards(AuthGuard('jwt'))
  @Post(':orderId/accept')
  async acceptOrder(@Param('orderId') orderId: string, @Req() req: Request) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.LIVREUR) {
      throw new ForbiddenException('Only deliverers can accept orders');
    }

    const delivererId = user.id;
    const updatedOrder = await this.ordersService.acceptOrder(
      orderId,
      delivererId,
    );
    return {
      success: true,
      order: {
        id: updatedOrder.id,
        status: updatedOrder.status,
        livreurId: updatedOrder.livreurId,
      },
    };
  }

  @UseGuards(AuthGuard('jwt'))
  @Get('partner')
  async getMyPartnerOrders(@Req() req: Request) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.RESTAURANT) {
      throw new ForbiddenException('Only partners can access this endpoint');
    }
    return this.ordersService.findByRestaurant(user.id);
  }

  @UseGuards(AuthGuard('jwt'))
  @Patch(':orderId/confirm')
  async confirmOrder(@Param('orderId') orderId: string, @Req() req: Request) {
    const user = req.user as { id: string; role: Role };
    const updatedOrder = await this.ordersService.acceptAndConfirmOrder(
      orderId,
      user,
    );
    return {
      success: true,
      order: {
        id: updatedOrder.id,
        status: updatedOrder.status,
      },
    };
  }

  @UseGuards(AuthGuard('jwt'))
  @Patch(':orderId/confirm-delivery')
  async confirmDelivery(
    @Param('orderId') orderId: string,
    @Req() req: Request,
  ) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.CLIENT) {
      throw new ForbiddenException('Only clients can confirm delivery');
    }

    const updatedOrder = await this.ordersService.confirmDelivery(
      orderId,
      user.id,
    );

    return {
      success: true,
      order: {
        id: updatedOrder.id,
        status: updatedOrder.status,
      },
    };
  }

  @UseGuards(AuthGuard('jwt'))
  @Patch(':orderId/ready')
  async markOrderReady(@Param('orderId') orderId: string, @Req() req: Request) {
    const user = req.user as { id: string; role: Role };
    const updatedOrder = await this.ordersService.markOrderReady(orderId, user);
    return {
      success: true,
      order: {
        id: updatedOrder.id,
        status: updatedOrder.status,
      },
    };
  }

  @UseGuards(AuthGuard('jwt'))
  @Get('can-deliver')
  async canDeliver(@Query('restaurantId') restaurantId: string) {
    return this.ordersService.canDeliver(restaurantId);
  }

  @UseGuards(AuthGuard('jwt'))
  @Post('qr/validate')
  async validateQr(
    @Body('token') token: string,
    @Req() req: Request,
  ): Promise<{
    success: boolean;
    message: string;
    orderId?: string;
    orderStatus?: string;
    collectionMethod?: string | null;
  }> {
    if (!token || !token.trim()) {
      throw new BadRequestException({
        code: 'QR_TOKEN_REQUIRED',
        message: 'QR token is required',
      });
    }

    const user = req.user as { id: string; role: Role };
    return this.ordersService.validatePickupQrScan(token.trim(), {
      id: user.id,
      role: user.role,
    });
  }
}
