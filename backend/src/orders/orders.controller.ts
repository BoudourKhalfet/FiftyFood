import {
  Controller,
  Post,
  Body,
  Req,
  Get,
  UseGuards,
  NotFoundException,
  Param,
  ForbiddenException,
  Patch,
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

  @Get()
  async getAllOrders() {
    return this.ordersService.findAllOrders();
  }
  @Get(':orderId/tracking')
  async getOrderTracking(@Param('orderId') orderId: string) {
    console.log('Controller: /orders/:orderId/tracking HIT with', orderId);
    const tracking = await this.ordersService.getOrderTracking(orderId);
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
  @Post(':orderId/accept')
  async acceptOrder(@Param('orderId') orderId: string, @Req() req: Request) {
    const delivererId = (req.user as { id: string }).id;
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
  async confirmOrder(@Param('orderId') orderId: string) {
    const updatedOrder =
      await this.ordersService.acceptAndConfirmOrder(orderId);
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
  async markOrderReady(@Param('orderId') orderId: string) {
    const updatedOrder = await this.ordersService.markOrderReady(orderId);
    return {
      success: true,
      order: {
        id: updatedOrder.id,
        status: updatedOrder.status,
      },
    };
  }
}
