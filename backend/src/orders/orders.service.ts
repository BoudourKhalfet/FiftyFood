import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderSummary } from './order-summary.interface';
import { customAlphabet } from 'nanoid';

const nanoid = customAlphabet('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 8);

@Injectable()
export class OrdersService {
  constructor(private prisma: PrismaService) {}

  async create(
    createOrderDto: CreateOrderDto,
    clientId: string,
  ): Promise<OrderSummary> {
    // Generate unique reference
    let unique = false;
    let reference = '';
    while (!unique) {
      reference = nanoid();
      const found = await this.prisma.order.findUnique({
        where: { reference },
      });
      if (!found) unique = true;
    }

    // Note: Adapt 'items' as Json type if appropriate to your schema
    const order = await this.prisma.order.create({
      data: {
        ...createOrderDto,

        clientId,
        reference,
        // Optionally: status: 'PENDING', etc. as per your schema
      },
    });

    // Optionally get restaurant name for client
    const restaurant = await this.prisma.restaurantProfile.findUnique({
      where: { userId: order.restaurantId },
    });

    // Compose type-safe summary response
    // You may add additional fields if needed
    return {
      id: order.id,
      reference: order.reference,
      pickupTime:
        order.collectionMethod === 'PICKUP'
          ? (order.items as { pickupTime?: string }).pickupTime
          : undefined,
      restaurantName: restaurant?.restaurantName ?? '',
      // Add more fields as necessary
    };
  }
}
