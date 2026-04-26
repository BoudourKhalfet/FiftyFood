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

  // =========================
  // STRIPE PAYMENT INTENT
  // =========================
  async createStripeIntent(params: {
    orderId: string;
    userId: string;
    amount: number;
    email?: string;
  }) {
    const order = await this.prisma.order.findUnique({
      where: { id: params.orderId },
    });

    if (!order) throw new BadRequestException('Order not found');

    if (order.clientId !== params.userId && order.restaurantId !== params.userId) {
      throw new BadRequestException('Unauthorized');
    }

    const intent = await this.stripeService.createPaymentIntent({
      orderId: params.orderId,
      amount: order.total,
      email: params.email,
    });

    // ❌ DO NOT change order status here
    // payment is not confirmed yet

    return intent;
  }

  // =========================
  // KONNECT PAYMENT
  // =========================
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

    if (!order) throw new BadRequestException('Order not found');

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

    // optional tracking only (NOT order status)
    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        paymentMethod: 'KONNECT',
      },
    });

    return {
      paymentUrl: konnectPayment.paymentUrl,
      paymentId: konnectPayment.paymentId,
    };
  }

  // =========================
  // PAYPAL PAYMENT
  // =========================
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

    if (!order) throw new BadRequestException('Order not found');

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

  // =========================
  // STRIPE CONFIRM (PAYMENT INTENT)
  // =========================
  async confirmStripePayment(orderId: string, paymentIntentId: string) {
    const confirmation = await this.stripeService.confirmPayment(paymentIntentId);

    if (confirmation.status === 'succeeded') {
      await this.updateOrderStatus(orderId, 'PAID');
    } else if (confirmation.status === 'requires_payment_method') {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return confirmation;
  }

  // =========================
  // STRIPE CHECKOUT SESSION
  // =========================
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

    if (!order) throw new BadRequestException('Order not found');

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

    return session;
  }

  // =========================
  // STRIPE CHECKOUT CONFIRM
  // =========================
  async confirmStripeCheckoutSession(sessionId: string, orderId: string) {
    const confirmation = await this.stripeService.confirmCheckoutSession(sessionId);

    if (confirmation.status === 'paid') {
      await this.updateOrderStatus(orderId, 'PAID');
    } else if (confirmation.status === 'unpaid') {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return confirmation;
  }

  // =========================
  // KONNECT VERIFY
  // =========================
  async verifyKonnectPayment(paymentId: string, orderId: string) {
    const verification = await this.konnectService.verifyPayment(paymentId);

    if (verification.isSuccessful) {
      await this.updateOrderStatus(orderId, 'PAID');
    } else {
      await this.updateOrderStatus(orderId, 'FAILED');
    }

    return verification;
  }

  // =========================
  // PAYPAL CAPTURE
  // =========================
  async capturePayPalPayment(
    paypalOrderId: string,
    orderId: string,
    userId?: string,
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) throw new BadRequestException('Order not found');

    if (
      userId &&
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

  // =========================
  // CORE STATUS UPDATE
  // =========================
  private async updateOrderStatus(orderId: string, paymentStatus: string) {
    let orderStatus = 'PENDING';

    if (paymentStatus === 'PAID') {
      orderStatus = 'CONFIRMED';
    } else if (paymentStatus === 'FAILED') {
      orderStatus = 'CANCELLED';
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: orderStatus as any,
      },
    });
  }
}