import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from './services/stripe.service';
import { KonnectService } from './services/konnect.service';
import { PayPalService } from './services/paypal.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private prisma: PrismaService,
    private stripeService: StripeService,
    private konnectService: KonnectService,
    private paypalService: PayPalService,
  ) {}

  /**
   * Create Stripe payment intent
   */
  async createStripeIntent(params: {
    orderId: string;
    userId: string;
    amount: number;
    email?: string;
  }) {
    const order = await this.prisma.order.findUnique({
      where: { id: params.orderId },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    if (order.clientId !== params.userId && order.restaurantId !== params.userId) {
      throw new BadRequestException('Unauthorized');
    }

    // ✅ FIX: use DB amount instead of frontend amount
    const intent = await this.stripeService.createPaymentIntent({
      orderId: params.orderId,
      amount: order.total,
      email: params.email,
    });

    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        status: 'PENDING' as any,
      },
    });

    return intent;
  }

  /**
   * Create Konnect (E-Dinar) payment
   */
  async createKonnectPayment(params: {
    orderId: string;
    userId: string;
    firstName: string;
    lastName: string;
    email: string;
    phone?: string;
  }) {
    const order = await this.prisma.order.findUnique({
      where: { id: params.orderId },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    if (order.clientId !== params.userId && order.restaurantId !== params.userId) {
      throw new BadRequestException('Unauthorized');
    }

    const konnectPayment = await this.konnectService.createPayment({
      orderId: params.orderId,
      amount: order.total,
      firstName: params.firstName,
      lastName: params.lastName,
      email: params.email,
      phone: params.phone,
    });

    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        status: 'PENDING' as any,
      },
    });

    return {
      paymentUrl: konnectPayment.paymentUrl,
      paymentId: konnectPayment.paymentId,
    };
  }

  /**
   * Create PayPal payment
   */
  async createPayPalPayment(params: {
    orderId: string;
    userId: string;
    amount?: number;
    returnUrl?: string;
    cancelUrl?: string;
  }) {
    const order = await this.prisma.order.findUnique({
      where: { id: params.orderId },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    if (order.clientId !== params.userId && order.restaurantId !== params.userId) {
      throw new BadRequestException('Unauthorized');
    }

    const paypalOrder = await this.paypalService.createOrder({
      orderId: params.orderId,
      amount: order.total,
      returnUrl: params.returnUrl,
      cancelUrl: params.cancelUrl,
    });

    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        status: 'PENDING' as any,
        paymentMethod: 'PAYPAL',
        paymentDetails: {
          provider: 'paypal',
          paypalOrderId: paypalOrder.paypalOrderId,
          approvalUrl: paypalOrder.approvalUrl,
          mode: paypalOrder.mode,
        } as any,
      },
    });

    return {
      approvalUrl: paypalOrder.approvalUrl,
      paypalOrderId: paypalOrder.paypalOrderId,
    };
  }

  async verifyKonnectPayment(paymentId: string, orderId: string) {
    const verification = await this.konnectService.verifyPayment(paymentId);

    if (verification.isSuccessful) {
      await this.updateOrderStatus(orderId, 'PAID');
    } else {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return verification;
  }

  async capturePayPalPayment(
    paypalOrderId: string,
    orderId: string,
    userId?: string,
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    if (
      userId != null &&
      order.clientId !== userId &&
      order.restaurantId !== userId
    ) {
      throw new BadRequestException('Unauthorized');
    }

    const capture = await this.paypalService.captureOrder(paypalOrderId);

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        paymentDetails: {
          provider: 'paypal',
          paypalOrderId,
          captureStatus: capture.status,
          capturedAmount: capture.amount,
          mode: capture.mode,
        } as any,
      },
    });

    if (capture.isSuccessful) {
      await this.updateOrderStatus(orderId, 'PAID');
    } else {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return capture;
  }

  async confirmStripePayment(orderId: string, paymentIntentId: string) {
    const confirmation = await this.stripeService.confirmPayment(paymentIntentId);

    if (confirmation.status === 'succeeded') {
      await this.updateOrderStatus(orderId, 'PAID');
    } else if (confirmation.status === 'requires_payment_method') {
      // keep pending
    } else {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return confirmation;
  }

  async createStripeCheckoutSession(params: {
    orderId: string;
    userId: string;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
  }) {
    const order = await this.prisma.order.findUnique({
      where: { id: params.orderId },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    if (order.clientId !== params.userId && order.restaurantId !== params.userId) {
      throw new BadRequestException('Unauthorized');
    }

    const session = await this.stripeService.createCheckoutSession({
      orderId: params.orderId,
      amount: order.total,
      email: params.email,
      successUrl: params.successUrl,
      cancelUrl: params.cancelUrl,
    });

    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        status: 'PENDING' as any,
      },
    });

    return session;
  }

  async confirmStripeCheckoutSession(sessionId: string, orderId: string) {
    const confirmation = await this.stripeService.confirmCheckoutSession(
      sessionId,
    );

    if (confirmation.status === 'paid') {
      await this.updateOrderStatus(orderId, 'PAID');
    } else if (confirmation.status === 'unpaid') {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return confirmation;
  }

  private async updateOrderStatus(orderId: string, paymentStatus: string) {
    let orderStatus = 'PENDING';

    if (paymentStatus === 'PAID') {
      orderStatus = 'CONFIRMED';
    } else if (paymentStatus === 'FAILED') {
      orderStatus = 'CANCELLED';
    }

    await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          status: true,
          offerId: true,
          items: true,
        },
      });

      if (!order) {
        throw new BadRequestException('Order not found');
      }

      if (paymentStatus === 'PAID' && order.status !== 'CONFIRMED') {
        const quantityOrdered = this.extractOrderedQuantity(order.items);

        await tx.offer.update({
          where: { id: order.offerId },
          data: { quantity: { decrement: quantityOrdered } },
        });

        const updatedOffer = await tx.offer.findUnique({
          where: { id: order.offerId },
          select: { quantity: true },
        });

        if (updatedOffer && updatedOffer.quantity <= 0) {
          await tx.offer.update({
            where: { id: order.offerId },
            data: { status: 'SOLD_OUT' as any },
          });
        }
      }

      await tx.order.update({
        where: { id: orderId },
        data: {
          status: orderStatus as any,
        },
      });
    });
  }

  private extractOrderedQuantity(items: unknown): number {
    try {
      if (items == null) return 1;

      if (typeof items === 'string') {
        const parsed = JSON.parse(items) as unknown;
        return this.extractOrderedQuantity(parsed);
      }

      if (Array.isArray(items)) {
        const first = items[0] as { quantity?: unknown } | undefined;
        const qty = Number(first?.quantity ?? 1);
        return Number.isFinite(qty) && qty > 0 ? Math.floor(qty) : 1;
      }

      if (typeof items === 'object') {
        const obj = items as { quantity?: unknown };
        const qty = Number(obj.quantity ?? 1);
        return Number.isFinite(qty) && qty > 0 ? Math.floor(qty) : 1;
      }
    } catch {
      return 1;
    }

    return 1;
  }
}