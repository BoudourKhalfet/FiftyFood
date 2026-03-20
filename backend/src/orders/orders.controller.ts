import { Controller, Post, Body, Req } from '@nestjs/common';
import { Request } from 'express';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderSummary } from './order-summary.interface';

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
}
