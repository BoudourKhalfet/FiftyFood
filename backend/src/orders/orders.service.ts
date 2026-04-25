import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderSummary } from './order-summary.interface';
import { customAlphabet } from 'nanoid';
import * as crypto from 'crypto';
import { Prisma, Role } from '@prisma/client';

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

type Coordinates = { lat: number; lng: number };

type QrPayload = {
  oid: string;
  ref: string;
  role: 'CLIENT' | 'DELIVERER';
  exp: number;
  nonce: string;
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
export class OrdersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersService.name);
  private expirationTimer?: NodeJS.Timeout;

  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    await this.expirePendingOrdersPastPickupTime();
    this.expirationTimer = setInterval(() => {
      void this.expirePendingOrdersPastPickupTime().catch((error: unknown) => {
        this.logger.error('Failed to expire pending orders', error as Error);
      });
    }, 60_000);
  }

  onModuleDestroy() {
    if (this.expirationTimer) {
      clearInterval(this.expirationTimer);
      this.expirationTimer = undefined;
    }
  }

  private getQrSecret(): string {
    return process.env.QR_SECRET || process.env.JWT_SECRET || 'dev_qr_secret';
  }

  private toBase64Url(input: Buffer | string): string {
    return Buffer.from(input)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/g, '');
  }

  private fromBase64Url(input: string): string {
    const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
    const padding = '='.repeat((4 - (normalized.length % 4)) % 4);
    return Buffer.from(`${normalized}${padding}`, 'base64').toString('utf8');
  }

  private signQrPayload(payloadB64: string): string {
    return this.toBase64Url(
      crypto
        .createHmac('sha256', this.getQrSecret())
        .update(payloadB64)
        .digest(),
    );
  }

  private makeSecureQrToken(payload: QrPayload): string {
    const payloadB64 = this.toBase64Url(JSON.stringify(payload));
    const sig = this.signQrPayload(payloadB64);
    return `${payloadB64}.${sig}`;
  }

  private parseAndVerifyQrToken(token: string): QrPayload {
    const [payloadB64, sig] = token.split('.');
    if (!payloadB64 || !sig) {
      throw new BadRequestException({
        code: 'QR_TOKEN_FORMAT_INVALID',
        message: 'Invalid QR token format',
      });
    }

    const expectedSig = this.signQrPayload(payloadB64);
    if (expectedSig !== sig) {
      throw new BadRequestException({
        code: 'QR_TOKEN_SIGNATURE_INVALID',
        message: 'Invalid QR token signature',
      });
    }

    let parsed: QrPayload;
    try {
      parsed = JSON.parse(this.fromBase64Url(payloadB64)) as QrPayload;
    } catch {
      throw new BadRequestException({
        code: 'QR_TOKEN_PAYLOAD_INVALID',
        message: 'Invalid QR token payload',
      });
    }

    if (
      !parsed.oid ||
      !parsed.ref ||
      !parsed.role ||
      !parsed.exp ||
      !parsed.nonce
    ) {
      throw new BadRequestException({
        code: 'QR_TOKEN_PAYLOAD_MALFORMED',
        message: 'Malformed QR token payload',
      });
    }

    return parsed;
  }

  private sha256(input: string): string {
    return crypto.createHash('sha256').update(input).digest('hex');
  }

  private async issuePickupQrToken(order: {
    id: string;
    reference: string;
    collectionMethod: string | null;
  }): Promise<string> {
    const role = order.collectionMethod === 'DELIVERY' ? 'DELIVERER' : 'CLIENT';
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const token = this.makeSecureQrToken({
      oid: order.id,
      ref: order.reference,
      role,
      exp: expiresAt.getTime(),
      nonce: crypto.randomBytes(16).toString('hex'),
    });

    await this.prisma.$executeRaw`
      UPDATE "Order"
      SET
        "pickupQrTokenHash" = ${this.sha256(token)},
        "pickupQrExpiresAt" = ${expiresAt},
        "pickupQrUsedAt" = NULL,
        "pickupQrStatus" = 'NOT_SCANNED'::"QrStatus"
      WHERE "id" = ${order.id}
    `;

    return token;
  }

  private getQrDisplayCode(
    orderCode: string,
    collectionMethod?: string | null,
  ) {
    if ((collectionMethod ?? '').toUpperCase() === 'PICKUP') {
      return orderCode.replace(/^DEL/i, 'PUP');
    }

    return orderCode;
  }

  private getOrderDisplayCode(
    orderCode: string,
    collectionMethod?: string | null,
  ) {
    return this.getQrDisplayCode(orderCode, collectionMethod);
  }
  private canIssueQrForOrder(order: {
    status: string;
    pickupQrStatus?: string | null;
    pickupQrUsedAt?: Date | null;
  }): boolean {
    if (order.pickupQrUsedAt != null || order.pickupQrStatus === 'USED') {
      return false;
    }
    if (order.pickupQrStatus === 'EXPIRED') {
      return false;
    }
    return !['DELIVERED', 'CANCELLED', 'EXPIRED'].includes(order.status);
  }

  private getPickupDeadline(
    pickupDateTime: Date | null,
    pickupTime?: string | null,
  ): Date | null {
    if (!pickupDateTime) return null;

    const source = (pickupTime ?? '').trim();
    if (!source) return pickupDateTime;

    const timePart = source.includes('-')
      ? (source.split('-').pop()?.trim() ?? '')
      : source;
    const match = timePart.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return pickupDateTime;

    const hour = Number(match[1]);
    const minute = Number(match[2]);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
      return pickupDateTime;
    }

    const deadline = new Date(pickupDateTime);
    deadline.setHours(hour, minute, 0, 0);
    return deadline;
  }

  private async expirePendingOrdersPastPickupTime() {
    await this.prisma.order.updateMany({
      where: {
        status: 'PENDING',
      },
      data: {
        status: 'CONFIRMED',
      },
    });

    const pendingOrders = await this.prisma.order.findMany({
      where: {
        status: {
          in: ['CONFIRMED', 'READY'],
        },
        pickupQrUsedAt: null,
        pickupQrStatus: {
          not: 'USED',
        },
      },
      select: {
        id: true,
        offerId: true,
      },
    });

    if (!pendingOrders.length) {
      return;
    }

    const offers = await this.prisma.offer.findMany({
      where: {
        id: {
          in: pendingOrders.map((order) => order.offerId),
        },
      },
      select: {
        id: true,
        status: true,
        pickupTime: true,
        pickupDateTime: true,
      },
    });

    const offerById = new Map(offers.map((offer) => [offer.id, offer]));

    const expiredOrderIds = pendingOrders
      .filter((order) => {
        const offer = offerById.get(order.offerId);
        if (!offer) {
          return false;
        }

        if (offer.status === 'EXPIRED') {
          return true;
        }

        const deadline = this.getPickupDeadline(
          offer.pickupDateTime,
          offer.pickupTime,
        );
        return deadline != null && deadline.getTime() <= Date.now();
      })
      .map((order) => order.id);

    if (!expiredOrderIds.length) {
      return;
    }

    await this.prisma.$executeRaw`
      UPDATE "Order"
      SET "status" = 'EXPIRED'::"OrderStatus",
          "updatedAt" = NOW()
      WHERE "id" IN (${Prisma.join(expiredOrderIds)})
    `;
  }

  private normalizeText(value?: string | null): string {
    return (value ?? '').trim().toLowerCase();
  }

  private async geocodeAddress(query: string): Promise<Coordinates | null> {
    const q = this.normalizeText(query);
    if (!q) return null;

    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(q)}`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'FiftyFood/1.0 (delivery-availability)',
        },
      });

      if (!response.ok) return null;

      const rows = (await response.json()) as Array<{
        lat: string;
        lon: string;
      }>;
      if (!rows.length) return null;

      const lat = Number(rows[0].lat);
      const lng = Number(rows[0].lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

      return { lat, lng };
    } catch {
      return null;
    }
  }

  private distanceKm(a: Coordinates, b: Coordinates): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const dLat = toRad(b.lat - a.lat);
    const dLng = toRad(b.lng - a.lng);
    const sinLat = Math.sin(dLat / 2);
    const sinLng = Math.sin(dLng / 2);

    const hav =
      sinLat * sinLat +
      Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinLng * sinLng;

    return 2 * earthRadiusKm * Math.asin(Math.sqrt(hav));
  }

  async create(
    createOrderDto: CreateOrderDto,
    clientId: string,
  ): Promise<OrderSummary> {
    const collectionMethodRaw = (
      createOrderDto.collectionMethod ?? 'PICKUP'
    ).toUpperCase();
    const collectionMethod =
      collectionMethodRaw === 'DELIVERY' ? 'DELIVERY' : 'PICKUP';

    if (collectionMethod === 'DELIVERY') {
      if (!createOrderDto.deliveryAddress || !createOrderDto.deliveryPhone) {
        throw new BadRequestException(
          'Delivery address and phone are required for delivery orders',
        );
      }

      const availability = await this.canDeliver(createOrderDto.restaurantId);
      if (!availability.available) {
        throw new BadRequestException(
          'No deliverers available right now. Please choose pickup.',
        );
      }
    }

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
        collectionMethod,
        clientId,
        reference,
        offerId,
        orderCode: generatedOrderCode,
        status: 'CONFIRMED',
      },
    });
    const pickupQrToken = await this.issuePickupQrToken(order);
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
      pickupQrToken,
      pickupQrDisplay: this.getQrDisplayCode(
        order.orderCode,
        order.collectionMethod,
      ),
      pickupTime:
        order.collectionMethod === 'PICKUP' ? mainItem?.pickupTime : undefined,
      restaurantName: restaurant?.restaurantName ?? '',
    };
  }

  async findByClient(clientId: string) {
    await this.expirePendingOrdersPastPickupTime();

    const orders = await this.prisma.order.findMany({
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
    });

    const mapped = await Promise.all(
      orders.map(async (order) => {
        const pickupQrToken = this.canIssueQrForOrder(order)
          ? await this.issuePickupQrToken({
              id: order.id,
              reference: order.reference,
              collectionMethod: order.collectionMethod,
            })
          : null;

        return {
          id: order.id,
          reference: order.reference,
          pickupQrToken,
          pickupQrDisplay: this.getQrDisplayCode(
            order.orderCode,
            order.collectionMethod,
          ),
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
        };
      }),
    );

    return mapped;
  }

  async findAllOrders() {
    await this.expirePendingOrdersPastPickupTime();

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
          orderDisplayCode: this.getOrderDisplayCode(
            order.orderCode,
            order.collectionMethod,
          ),
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

  async getOrderTracking(
    orderId: string,
    requester: { id: string; role: Role },
  ) {
    await this.expirePendingOrdersPastPickupTime();

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
            clientProfile: {
              select: {
                fullName: true,
                phone: true,
                locationConsentGiven: true,
                lastLatitude: true,
                lastLongitude: true,
              },
            },
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
                lastLatitude: true,
                lastLongitude: true,
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

    const isOwnerClient =
      requester.role === Role.CLIENT && order.clientId === requester.id;
    const isAssignedDeliverer =
      requester.role === Role.LIVREUR && order.livreurId === requester.id;
    const isOwnerRestaurant =
      requester.role === Role.RESTAURANT && order.restaurantId === requester.id;
    const isAdmin = requester.role === Role.ADMIN;

    if (
      !isOwnerClient &&
      !isAssignedDeliverer &&
      !isOwnerRestaurant &&
      !isAdmin
    ) {
      throw new ForbiddenException('You are not allowed to view this tracking');
    }

    const mainItem = getMainItem(order.items);

    const pickupQrFor =
      order.collectionMethod === 'PICKUP' ? 'CLIENT' : 'DELIVERER';

    const pickupQrData = this.canIssueQrForOrder(order)
      ? await this.issuePickupQrToken({
          id: order.id,
          reference: order.reference,
          collectionMethod: order.collectionMethod,
        })
      : null;

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
      delivered:
        order.status === 'DELIVERED' ||
        (order.collectionMethod === 'PICKUP' && order.status === 'PICKED_UP'),
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
      clientLocation:
        order.client?.clientProfile?.locationConsentGiven &&
        typeof order.client?.clientProfile?.lastLatitude === 'number' &&
        typeof order.client?.clientProfile?.lastLongitude === 'number'
          ? `${order.client.clientProfile.lastLatitude},${order.client.clientProfile.lastLongitude}`
          : '',
      delivererLocation:
        order.livreur?.livreurProfile?.locationConsentGiven &&
        typeof order.livreur?.livreurProfile?.lastLatitude === 'number' &&
        typeof order.livreur?.livreurProfile?.lastLongitude === 'number'
          ? `${order.livreur.livreurProfile.lastLatitude},${order.livreur.livreurProfile.lastLongitude}`
          : '',
      pickupQrFor,
      pickupQrData,
      pickupQrDisplay: this.getQrDisplayCode(
        order.orderCode,
        order.collectionMethod,
      ),
      locationConsentGiven:
        order.livreur?.livreurProfile?.locationConsentGiven ?? false,
      delivererPhone: order.livreur?.livreurProfile?.phone ?? '',
    };

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

  async findHistoryForDeliverer(delivererId: string) {
    return this.prisma.order
      .findMany({
        where: {
          livreurId: delivererId,
          status: 'DELIVERED',
        },
        include: {
          restaurant: { include: { restaurantProfile: true } },
          client: { include: { clientProfile: true } },
          reviews: {
            select: {
              rating: true,
            },
            orderBy: { createdAt: 'desc' },
            take: 1,
          },
          offer: true,
        },
        orderBy: { updatedAt: 'desc' },
      })
      .then((orders) =>
        orders.map((order) => ({
          id: order.id,
          orderCode: order.orderCode,
          orderDisplayCode: this.getOrderDisplayCode(
            order.orderCode,
            order.collectionMethod,
          ),
          restaurantName:
            order.restaurant?.restaurantProfile?.restaurantName ?? '',
          customerName: order.client?.clientProfile?.fullName ?? '',
          date: order.updatedAt,
          amount: order.deliveryFee ?? order.total ?? 0,
          rating: order.reviews?.[0]?.rating ?? 5,
          status: order.status,
          deliveryAddress: order.deliveryAddress ?? '',
        })),
      );
  }

  async acceptOrder(orderId: string, delivererId: string) {
    await this.expirePendingOrdersPastPickupTime();

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
    if (!['CONFIRMED'].includes(order.status))
      throw new Error('Order not available for assignment');

    return this.prisma.order.update({
      where: { id: orderId },
      data: {
        livreurId: delivererId,
        status: 'ASSIGNED',
      },
    });
  }

  async confirmDelivery(orderId: string, clientId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) throw new NotFoundException('Order not found');
    if (order.clientId !== clientId) {
      throw new ForbiddenException('You can only confirm your own orders');
    }
    if (order.collectionMethod !== 'DELIVERY') {
      throw new BadRequestException('Only delivery orders can be confirmed');
    }
    if (order.status === 'DELIVERED') return order;
    if (!['ASSIGNED', 'PICKED_UP', 'READY'].includes(order.status)) {
      throw new BadRequestException(
        'Order is not ready for delivery confirmation',
      );
    }

    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'DELIVERED' },
    });
  }

  async findByRestaurant(restaurantId: string) {
    await this.expirePendingOrdersPastPickupTime();

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

  async acceptAndConfirmOrder(
    orderId: string,
    actor: { id: string; role: Role },
  ) {
    await this.expirePendingOrdersPastPickupTime();

    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) throw new Error('Order not found');
    if (actor.role !== Role.RESTAURANT && actor.role !== Role.ADMIN) {
      throw new ForbiddenException('Only restaurants can confirm orders');
    }
    if (actor.role === Role.RESTAURANT && order.restaurantId !== actor.id) {
      throw new ForbiddenException('You can only confirm your own orders');
    }

    // Orders are now auto-confirmed when payment succeeds.
    return order;
  }

  async validatePickupQrScan(
    token: string,
    actor: { id: string; role: Role },
  ): Promise<{
    success: boolean;
    message: string;
    orderId?: string;
    orderStatus?: string;
    collectionMethod?: string | null;
  }> {
    await this.expirePendingOrdersPastPickupTime();

    const parsed = this.parseAndVerifyQrToken(token);
    const tokenHash = this.sha256(token);

    const rows = await this.prisma.$queryRaw<
      Array<{
        id: string;
        reference: string;
        status: string;
        collectionMethod: string | null;
        restaurantId: string;
        livreurId: string | null;
        pickupQrTokenHash: string | null;
        pickupQrExpiresAt: Date | null;
        pickupQrUsedAt: Date | null;
        pickupQrStatus: string | null;
      }>
    >`
      SELECT
        "id",
        "reference",
        "status"::text AS "status",
        "collectionMethod"::text AS "collectionMethod",
        "restaurantId",
        "livreurId",
        "pickupQrTokenHash",
        "pickupQrExpiresAt",
        "pickupQrUsedAt",
        "pickupQrStatus"::text AS "pickupQrStatus"
      FROM "Order"
      WHERE "id" = ${parsed.oid}
      LIMIT 1
    `;
    const order = rows[0];

    if (!order) {
      throw new NotFoundException({
        code: 'QR_ORDER_NOT_FOUND',
        message: 'Order not found for this QR token',
      });
    }

    if (actor.role !== Role.RESTAURANT) {
      throw new ForbiddenException({
        code: 'QR_ROLE_NOT_ALLOWED',
        message: 'Only restaurant accounts can validate pickup QR',
      });
    }

    if (order.restaurantId !== actor.id) {
      throw new ForbiddenException({
        code: 'QR_RESTAURANT_MISMATCH',
        message: 'This QR does not belong to your restaurant',
      });
    }

    if (order.reference !== parsed.ref) {
      throw new BadRequestException({
        code: 'QR_REFERENCE_MISMATCH',
        message: 'QR reference mismatch',
      });
    }

    const expectedRole =
      order.collectionMethod === 'DELIVERY' ? 'DELIVERER' : 'CLIENT';
    if (parsed.role !== expectedRole) {
      throw new BadRequestException({
        code: 'QR_TOKEN_ROLE_MISMATCH',
        message: 'QR token role does not match order collection method',
      });
    }

    if (!order.pickupQrTokenHash || order.pickupQrTokenHash !== tokenHash) {
      throw new BadRequestException({
        code: 'QR_TOKEN_INVALID',
        message: 'Invalid QR token',
      });
    }

    const expired =
      parsed.exp < Date.now() ||
      (order.pickupQrExpiresAt != null &&
        new Date(order.pickupQrExpiresAt).getTime() < Date.now());

    if (expired) {
      await this.prisma.$executeRaw`
        UPDATE "Order"
        SET "pickupQrStatus" = 'EXPIRED'::"QrStatus"
        WHERE "id" = ${order.id}
      `;
      throw new BadRequestException({
        code: 'QR_TOKEN_EXPIRED',
        message: 'QR token expired',
      });
    }

    if (order.pickupQrUsedAt || order.pickupQrStatus === 'USED') {
      throw new BadRequestException({
        code: 'QR_TOKEN_ALREADY_USED',
        message: 'QR token already used',
      });
    }

    if (order.collectionMethod === 'PICKUP') {
      if (!['CONFIRMED', 'READY'].includes(order.status)) {
        throw new BadRequestException({
          code: 'QR_PICKUP_STATUS_INVALID',
          message: 'Order is not eligible for pickup validation',
        });
      }

      await this.prisma.order.update({
        where: { id: order.id },
        data: {
          status: 'PICKED_UP',
        },
      });

      await this.prisma.$executeRaw`
        UPDATE "Order"
        SET
          "pickupQrStatus" = 'USED'::"QrStatus",
          "pickupQrUsedAt" = NOW()
        WHERE "id" = ${order.id}
      `;

      return {
        success: true,
        message:
          'QR validated. Pickup confirmed and order marked as picked up.',
        orderId: order.id,
        orderStatus: 'PICKED_UP',
        collectionMethod: order.collectionMethod,
      };
    }

    if (!['ASSIGNED', 'READY', 'CONFIRMED'].includes(order.status)) {
      throw new BadRequestException({
        code: 'QR_DELIVERY_STATUS_INVALID',
        message: 'Order is not eligible for delivery pickup validation',
      });
    }

    if (!order.livreurId) {
      throw new BadRequestException({
        code: 'QR_DELIVERER_MISSING',
        message: 'No deliverer assigned to this delivery order yet',
      });
    }

    await this.prisma.order.update({
      where: { id: order.id },
      data: {
        status: 'PICKED_UP',
      },
    });

    await this.prisma.$executeRaw`
      UPDATE "Order"
      SET
        "pickupQrStatus" = 'USED'::"QrStatus",
        "pickupQrUsedAt" = NOW()
      WHERE "id" = ${order.id}
    `;

    return {
      success: true,
      message: 'QR validated. Delivery order marked as picked up.',
      orderId: order.id,
      orderStatus: 'PICKED_UP',
      collectionMethod: order.collectionMethod,
    };
  }

  async markOrderReady(orderId: string, actor: { id: string; role: Role }) {
    await this.expirePendingOrdersPastPickupTime();

    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) throw new Error('Order not found');
    if (actor.role !== Role.RESTAURANT && actor.role !== Role.ADMIN) {
      throw new ForbiddenException('Only restaurants can mark orders ready');
    }
    if (actor.role === Role.RESTAURANT && order.restaurantId !== actor.id) {
      throw new ForbiddenException('You can only update your own orders');
    }
    if (order.status !== 'CONFIRMED' && order.status !== 'ASSIGNED')
      throw new Error('Order must be confirmed or assigned to be ready');

    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: 'READY' },
    });
  }

  async canDeliver(restaurantId: string) {
    console.log('[DELIVERY DEBUG] canDeliver called', { restaurantId });

    const restaurantRows = await this.prisma.$queryRaw<
      Array<{
        address: string | null;
        city: string | null;
        latitude: number | null;
        longitude: number | null;
      }>
    >`
      SELECT
        rp."address",
        rp."city",
        rp."latitude",
        rp."longitude"
      FROM "RestaurantProfile" rp
      WHERE rp."userId" = ${restaurantId}
      LIMIT 1
    `;

    if (!restaurantRows.length) {
      console.log('[DELIVERY DEBUG] restaurant profile not found for userId');
      return { available: false };
    }

    const restaurant = restaurantRows[0];
    console.log('[DELIVERY DEBUG] restaurant profile', restaurant);

    const restaurantAddress = this.normalizeText(restaurant.address);
    const restaurantCity = this.normalizeText(restaurant.city);
    if (!restaurantAddress && !restaurantCity) {
      console.log(
        '[DELIVERY DEBUG] restaurant address and city are both empty after normalization',
      );
      return { available: false, eligibleCount: 0 };
    }

    const maxDistanceKm = Number(process.env.DELIVERY_MAX_DISTANCE_KM ?? 10);
    const restaurantCoordsMismatchKm = Number(
      process.env.RESTAURANT_COORDS_MISMATCH_KM ?? 3,
    );
    let restaurantCoords: Coordinates | null = null;

    const restaurantQuery = [restaurant.address, restaurant.city]
      .filter((v) => !!this.normalizeText(v))
      .join(', ');

    if (
      typeof restaurant.latitude === 'number' &&
      typeof restaurant.longitude === 'number'
    ) {
      restaurantCoords = {
        lat: restaurant.latitude,
        lng: restaurant.longitude,
      };
      console.log(
        '[DELIVERY DEBUG] using stored restaurant coords',
        restaurantCoords,
      );

      if (restaurantQuery) {
        const geocodedRestaurantCoords =
          await this.geocodeAddress(restaurantQuery);
        if (geocodedRestaurantCoords) {
          const mismatchKm = this.distanceKm(
            restaurantCoords,
            geocodedRestaurantCoords,
          );

          console.log('[DELIVERY DEBUG] restaurant coords mismatch check', {
            stored: restaurantCoords,
            geocoded: geocodedRestaurantCoords,
            mismatchKm: Number(mismatchKm.toFixed(3)),
            restaurantCoordsMismatchKm,
          });

          if (mismatchKm > restaurantCoordsMismatchKm) {
            restaurantCoords = geocodedRestaurantCoords;
            await this.prisma.$executeRaw`
              UPDATE "RestaurantProfile"
              SET
                "latitude" = ${restaurantCoords.lat},
                "longitude" = ${restaurantCoords.lng},
                "lastGeocodedAt" = NOW()
              WHERE "userId" = ${restaurantId}
            `;
            console.log(
              '[DELIVERY DEBUG] corrected stale restaurant coords from geocoding',
              restaurantCoords,
            );
          }
        }
      }
    } else {
      console.log(
        '[DELIVERY DEBUG] geocoding restaurant query',
        restaurantQuery,
      );
      restaurantCoords = await this.geocodeAddress(restaurantQuery);
      console.log(
        '[DELIVERY DEBUG] geocoded restaurant coords',
        restaurantCoords,
      );

      if (restaurantCoords) {
        await this.prisma.$executeRaw`
          UPDATE "RestaurantProfile"
          SET
            "latitude" = ${restaurantCoords.lat},
            "longitude" = ${restaurantCoords.lng},
            "lastGeocodedAt" = NOW()
          WHERE "userId" = ${restaurantId}
        `;
        console.log('[DELIVERY DEBUG] stored restaurant coords in DB');
      }
    }

    if (!restaurantCoords) {
      console.log('[DELIVERY DEBUG] failed to resolve restaurant coordinates');
      return { available: false, eligibleCount: 0 };
    }

    const onlineWindowMinutes = Number(
      process.env.DELIVERY_ONLINE_WINDOW_MINUTES ?? 5,
    );

    console.log('[DELIVERY DEBUG] online window config', {
      onlineWindowMinutes,
      source: 'db-utc-now-minus-interval',
    });

    const onlineSnapshot = await this.prisma.$queryRaw<
      Array<{
        userId: string;
        status: string;
        lastOnlineAt: Date | null;
        utcNow: Date;
        utcCutoff: Date;
        isOnline: boolean;
      }>
    >`
      SELECT
        lp."userId",
        u."status"::text AS "status",
        lp."lastOnlineAt",
        timezone('UTC', NOW()) AS "utcNow",
        timezone('UTC', NOW()) - (${onlineWindowMinutes} * INTERVAL '1 minute') AS "utcCutoff",
        (
          lp."lastOnlineAt" >= timezone('UTC', NOW()) - (${onlineWindowMinutes} * INTERVAL '1 minute')
        ) AS "isOnline"
      FROM "LivreurProfile" lp
      JOIN "User" u ON u."id" = lp."userId"
      WHERE u."status" = 'APPROVED'
      ORDER BY lp."lastOnlineAt" DESC NULLS LAST
      LIMIT 5
    `;
    console.log(
      '[DELIVERY DEBUG] approved deliverers online snapshot',
      onlineSnapshot,
    );

    const delivererCounts = await this.prisma.$queryRaw<
      Array<{
        approvedCount: number;
        approvedOnlineCount: number;
      }>
    >`
      SELECT
        COUNT(*) FILTER (WHERE u."status" = 'APPROVED')::int AS "approvedCount",
        COUNT(*) FILTER (
          WHERE u."status" = 'APPROVED'
            AND lp."lastOnlineAt" >= timezone('UTC', NOW()) - (${onlineWindowMinutes} * INTERVAL '1 minute')
        )::int AS "approvedOnlineCount"
      FROM "LivreurProfile" lp
      JOIN "User" u ON u."id" = lp."userId"
    `;

    const countRow = delivererCounts[0] ?? {
      approvedCount: 0,
      approvedOnlineCount: 0,
    };
    console.log('[DELIVERY DEBUG] deliverer counts snapshot', countRow);

    const deliverers = await this.prisma.$queryRaw<
      Array<{
        userId: string;
        zone: string | null;
        locationConsentGiven: boolean;
        lastOnlineAt: Date | null;
        lastLatitude: number | null;
        lastLongitude: number | null;
      }>
    >`
      SELECT
        lp."userId",
        lp."zone",
        lp."locationConsentGiven",
        lp."lastOnlineAt",
        lp."lastLatitude",
        lp."lastLongitude"
      FROM "LivreurProfile" lp
      JOIN "User" u ON u."id" = lp."userId"
      WHERE lp."lastOnlineAt" >= timezone('UTC', NOW()) - (${onlineWindowMinutes} * INTERVAL '1 minute')
        AND u."status" = 'APPROVED'
    `;

    console.log(
      '[DELIVERY DEBUG] online approved deliverers count',
      deliverers.length,
    );

    // Current schema has no persisted deliverer lat/lng.
    // We geocode deliverer zone text and compute distance to restaurant.
    const zoneCoordsCache = new Map<string, Coordinates | null>();
    let eligibleCount = 0;

    for (const d of deliverers) {
      let coords: Coordinates | null = null;
      let coordsSource = 'zone';

      if (
        d.locationConsentGiven &&
        typeof d.lastLatitude === 'number' &&
        typeof d.lastLongitude === 'number'
      ) {
        coords = { lat: d.lastLatitude, lng: d.lastLongitude };
        coordsSource = 'live';
      } else {
        const zone = this.normalizeText(d.zone);
        if (!zone) {
          console.log(
            '[DELIVERY DEBUG] skipping deliverer: empty zone and no live coords',
            { userId: d.userId, zone: d.zone, lastOnlineAt: d.lastOnlineAt },
          );
          continue;
        }

        let cachedCoords = zoneCoordsCache.get(zone);
        if (cachedCoords === undefined) {
          console.log('[DELIVERY DEBUG] geocoding deliverer zone', zone);
          cachedCoords = await this.geocodeAddress(zone);
          console.log('[DELIVERY DEBUG] deliverer zone coords', {
            zone,
            coords: cachedCoords,
          });
          zoneCoordsCache.set(zone, cachedCoords);
        }
        coords = cachedCoords;
      }

      if (!coords) {
        console.log('[DELIVERY DEBUG] skipping deliverer: unresolved coords', {
          userId: d.userId,
          source: coordsSource,
          zone: d.zone,
        });
        continue;
      }

      const distance = this.distanceKm(coords, restaurantCoords);
      const isEligible = distance <= maxDistanceKm;
      console.log('[DELIVERY DEBUG] deliverer eligibility', {
        userId: d.userId,
        source: coordsSource,
        distanceKm: Number(distance.toFixed(3)),
        maxDistanceKm,
        isEligible,
        restaurantCoords,
        delivererCoords: coords,
      });

      if (isEligible) {
        eligibleCount += 1;
      }
    }

    console.log('[DELIVERY DEBUG] canDeliver result', {
      eligibleCount,
      available: eligibleCount > 0,
    });

    return { available: eligibleCount > 0, eligibleCount };
  }
}
