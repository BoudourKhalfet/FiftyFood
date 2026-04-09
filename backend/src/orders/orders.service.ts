import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderSummary } from './order-summary.interface';
import { customAlphabet } from 'nanoid';

const nanoid = customAlphabet('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 8);

type OfferItem = {
  offerId?: string;
  pickupTime?: string;
  name?: string;
  photoUrl?: string;
  discountedPrice?: number;
  quantity?: number;
  [key: string]: any;
};
function getMainItem(raw: unknown): OfferItem | undefined {
  try {
    const parsed: unknown = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (Array.isArray(parsed)) {
      return parsed[0] && typeof parsed[0] === 'object'
        ? (parsed[0] as OfferItem)
        : undefined;
    } else if (parsed && typeof parsed === 'object') {
      return parsed as OfferItem;
    }
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
      console.error('Failed to parse order.items:', err, 'Raw value:', raw);
    }
  }
  return undefined;
}

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

    const lastOrder = await this.prisma.order.findFirst({
      orderBy: { createdAt: 'desc' },
      select: { orderCode: true },
    });

    let newCodeNum = 1;
    if (lastOrder?.orderCode) {
      const match = lastOrder.orderCode.match(/\d+$/);
      if (match) newCodeNum = parseInt(match[0]) + 1;
    }
    const generatedOrderCode = 'DEL' + newCodeNum.toString().padStart(3, '0');

    const { offerId, ...orderData } = createOrderDto;
    if (!offerId) throw new Error('offerId is required');

    const order = await this.prisma.order.create({
      data: {
        ...orderData,
        clientId,
        reference,
        offerId,
        orderCode: generatedOrderCode,
      },
    });
    let quantityOrdered = 1;
    try {
      const mainItem = getMainItem(order.items);
      if (mainItem?.quantity) quantityOrdered = mainItem.quantity;
    } catch (err) {
      if (process.env.NODE_ENV !== 'production') {
        console.error('Failed to parse order.items or get quantity.', err);
      }
    }

    await this.prisma.offer.update({
      where: { id: offerId },
      data: { quantity: { decrement: quantityOrdered } },
    });

    // Optional: auto-pause when 0 (for safety, since getAvailableOffers hides qty==0)
    const updatedOffer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (updatedOffer && updatedOffer.quantity <= 0) {
      await this.prisma.offer.update({
        where: { id: offerId },
        data: { status: 'SOLD_OUT' },
      });
    }

    const restaurant = await this.prisma.restaurantProfile.findUnique({
      where: { userId: order.restaurantId },
    });

    const mainItem = getMainItem(order.items);

    return {
      id: order.id,
      reference: order.reference,
      pickupTime:
        order.collectionMethod === 'PICKUP' ? mainItem?.pickupTime : undefined,
      restaurantName: restaurant?.restaurantName ?? '',
    };
  }

  async findByClient(clientId: string) {
    return this.prisma.order
      .findMany({
        where: { clientId },
        include: {
          restaurant: {
            select: {
              restaurantProfile: { select: { restaurantName: true } },
            },
          },
          offer: {
            select: {
              description: true,
              pickupTime: true,
              discountedPrice: true,
              photoUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      })
      .then((orders) =>
        orders.map((order) => ({
          id: order.id,
          reference: order.reference,
          status: order.status,
          collectionMethod: order.collectionMethod,
          total: order.total,
          mealName: order.offer?.description ?? '',
          imageUrl: order.offer?.photoUrl ?? '',
          timeSlot: order.offer?.pickupTime ?? '',
          price: order.offer?.discountedPrice ?? '',
          createdAt: order.createdAt,
          restaurantName:
            order.restaurant?.restaurantProfile?.restaurantName ?? '',
        })),
      );
  }

  async findAllOrders() {
    return this.prisma.order
      .findMany({
        include: {
          client: { select: { clientProfile: true } },
          restaurant: { select: { restaurantProfile: true } },
          livreur: { select: { livreurProfile: true } },
          offer: {
            select: {
              description: true,
              pickupTime: true,
              discountedPrice: true,
              photoUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      })
      .then((orders) =>
        orders.map((order) => ({
          id: order.id,
          orderCode: order.orderCode,
          reference: order.reference,
          userName: order.client?.clientProfile?.fullName ?? '',
          restaurantName:
            order.restaurant?.restaurantProfile?.restaurantName ?? '',
          amount: order.total,
          method: order.collectionMethod,
          status: order.status,
          date: order.createdAt,
          deliverer:
            order.collectionMethod === 'DELIVERY'
              ? (order.livreur?.livreurProfile?.fullName ?? '')
              : '',
          offerTitle: order.offer?.description ?? '',
          offerPhoto: order.offer?.photoUrl ?? '',
        })),
      );
  }

  async getOrderTracking(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        restaurant: {
          select: {
            restaurantProfile: {
              select: {
                restaurantName: true,
                establishmentType: true,
                address: true,
                phone: true,
              },
            },
          },
        },
        client: {
          select: {
            clientProfile: { select: { fullName: true, phone: true } },
          },
        },
        livreur: {
          select: {
            livreurProfile: {
              select: {
                fullName: true,
                avgRating: true,
                vehicleType: true,
                locationConsentGiven: true,
                phone: true,
              },
            },
          },
        },
        offer: {
          select: {
            description: true,
            pickupTime: true,
            discountedPrice: true,
            photoUrl: true,
          },
        },
      },
    });
    if (!order) return null;

    const mainItem = getMainItem(order.items);

    const pickupQrFor =
      order.collectionMethod === 'PICKUP' ? 'CLIENT' : 'DELIVERER';

    const responseObject = {
      id: order.id,
      status: order.status,
      collectionMethod: order.collectionMethod,
      restaurantName: order.restaurant?.restaurantProfile?.restaurantName ?? '',
      mealName: order.offer?.description ?? '',
      timeSlot: order.offer?.pickupTime ?? '',
      date: order.createdAt.toISOString().slice(0, 10),
      price: order.offer?.discountedPrice ?? order.total ?? 0,
      reference: order.reference,
      delivered: order.status === 'DELIVERED',
      qr: false,
      imageUrl: order.offer?.photoUrl ?? '',
      deliveryAddress: order.deliveryAddress ?? '',
      quantity: typeof mainItem?.quantity === 'number' ? mainItem.quantity : 1,
      delivererRating: order.livreur?.livreurProfile?.avgRating ?? 0,
      delivererName: order.livreur?.livreurProfile?.fullName ?? '',
      delivererVehicle: order.livreur?.livreurProfile?.vehicleType ?? '',
      partnerLabel:
        order.restaurant?.restaurantProfile?.establishmentType ?? '',
      restaurantAddress: order.restaurant?.restaurantProfile?.address ?? '',
      restaurantPhone: order.restaurant?.restaurantProfile?.phone ?? '',
      clientName: order.client?.clientProfile?.fullName ?? '',
      clientPhone: order.client?.clientProfile?.phone ?? '',
      pickupQrFor,
      pickupQrData: order.reference,
      pickupQrDisplay: order.orderCode,
      locationConsentGiven:
        order.livreur?.livreurProfile?.locationConsentGiven ?? false,
      delivererPhone: order.livreur?.livreurProfile?.phone ?? '',
    };

    console.log('Order Tracking Response:', responseObject);

    return responseObject;
  }

  async findAvailableForDeliverer() {
    // 2. (Later: filter by  location, etc.)
    return this.prisma.order.findMany({
      where: {
        status: 'CONFIRMED',
        livreurId: null,
        collectionMethod: 'DELIVERY',
      },
      include: {
        restaurant: { include: { restaurantProfile: true } },
        client: { include: { clientProfile: true } },
        offer: true,
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async findActiveForDeliverer(delivererId: string) {
    return this.prisma.order.findMany({
      where: {
        livreurId: delivererId,

        status: {
          in: ['ASSIGNED', 'PICKED_UP'],
        },
      },
      include: {
        restaurant: { include: { restaurantProfile: true } },
        client: { include: { clientProfile: true } },
        offer: true,
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async acceptOrder(orderId: string, delivererId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    console.log(
      '[AcceptOrder] id:',
      orderId,
      'found:',
      !!order,
      'status:',
      order?.status,
      'livreurId:',
      order?.livreurId,
    );

    if (!order) throw new Error('Order not found');
    if (order.livreurId) throw new Error('Order already assigned');
    if (order.status !== 'PENDING')
      throw new Error('Order not available for assignment');

    return this.prisma.order.update({
      where: { id: orderId },
      data: {
        livreurId: delivererId,
        status: 'ASSIGNED',
      },
    });
  }

  async findByRestaurant(restaurantId: string) {
    return this.prisma.order
      .findMany({
        where: { restaurantId },
        include: {
          client: {
            select: {
              clientProfile: { select: { fullName: true } },
            },
          },
          offer: {
            select: {
              description: true,
              pickupTime: true,
              discountedPrice: true,
              photoUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      })
      .then((orders) =>
        orders.map((order) => ({
          id: order.id,
          orderCode: order.orderCode,
          reference: order.reference,
          status: order.status,
          method: order.collectionMethod,
          customerName: order.client?.clientProfile?.fullName ?? '',
          amount: order.total,
          pickupTime: order.offer?.pickupTime ?? '',
          offerTitle: order.offer?.description ?? '',
          offerPhoto: order.offer?.photoUrl ?? '',
          price: order.offer?.discountedPrice ?? '',
          createdAt: order.createdAt,
          itemsCount:
            typeof order.items === 'string'
              ? (getMainItem(order.items)?.quantity ?? 1)
              : (getMainItem(order.items)?.quantity ?? 1),
        })),
      );
  }

  async acceptAndConfirmOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new Error('Order not found');
    if (order.status !== 'PENDING')
      throw new Error('Order must be pending to be confirmed');
    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'CONFIRMED' },
    });
  }

  async markOrderReady(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new Error('Order not found');
    if (order.status !== 'CONFIRMED' && order.status !== 'ASSIGNED')
      throw new Error('Order must be confirmed or assigned to be ready');
    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'READY' },
    });
  }
}
