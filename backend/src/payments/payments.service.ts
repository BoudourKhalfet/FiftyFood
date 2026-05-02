import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from './services/stripe.service';
import { KonnectService } from './services/konnect.service';
import { PayPalService } from './services/paypal.service';
import { OrderStatus } from '@prisma/client';
import { OrdersService } from '../orders/orders.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private prisma: PrismaService,
    private stripeService: StripeService,
    private konnectService: KonnectService,
    private paypalService: PayPalService,
    private ordersService: OrdersService,
  ) {}

  private async findAndAuthorizeOrder(orderId: string, userId: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (order.clientId !== userId) throw new BadRequestException('Unauthorized');
    return order;
  }

  // =========================
  // STRIPE PAYMENT INTENT (no order created yet — created by webhook on success)
  // =========================
  async createStripeIntent(params: {
    clientId: string;
    restaurantId: string;
    offerId: string;
    items: any;
    total: number;
    collectionMethod?: string;
    deliveryAddress?: string;
    deliveryPhone?: string;
    deliveryFee?: number;
    email?: string;
    orderId?: string;
  }) {
    const verifiedTotal = await this.getVerifiedTotal(params.offerId, params.items, params.deliveryFee);

    const intent = await this.stripeService.createPaymentIntent({
      orderData: {
        clientId: params.clientId,
        restaurantId: params.restaurantId,
        offerId: params.offerId,
        items: params.items,
        total: verifiedTotal,
        collectionMethod: params.collectionMethod,
        deliveryAddress: params.deliveryAddress,
        deliveryPhone: params.deliveryPhone,
        deliveryFee: params.deliveryFee,
      },
      amount: verifiedTotal,
      email: params.email,
      orderId: params.orderId,
    });

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
    const order = await this.findAndAuthorizeOrder(params.orderId, params.userId);

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
        paymentMethod: 'D17',
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
    const order = await this.findAndAuthorizeOrder(params.orderId, params.userId);

    const paypalOrder = await this.paypalService.createOrder({
      orderId: params.orderId,
      amount: order.total,
      returnUrl: params.returnUrl,
      cancelUrl: params.cancelUrl,
    });

    await this.prisma.order.update({
      where: { id: params.orderId },
      data: {
        paymentMethod: 'PAYPAL' as any,
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
  // STRIPE CONFIRM INTENT (mobile fallback — webhook is source of truth)
  // =========================
  async confirmStripePayment(paymentIntentId: string, userId: string): Promise<{
    status: string;
    orderId?: string;
    orderStatus?: string;
    amount?: number;
  }> {
    const confirmation = await this.stripeService.confirmPayment(paymentIntentId);
    this.logger.log(`Stripe mobile confirm status: ${confirmation.status}`);

    if (confirmation.status === 'succeeded') {
      const orderId = confirmation.orderId;
      if (orderId) {
        await this.updateOrderStatus(orderId, 'CONFIRMED');
        await this.prisma.order.update({
          where: { id: orderId },
          data: {
            paymentDetails: {
              stripePaymentIntentId: paymentIntentId,
              provider: 'stripe',
              confirmedAt: new Date().toISOString(),
            } as any,
          },
        });
        return { status: confirmation.status, orderId, amount: confirmation.amount };
      }
    }

    return { status: confirmation.status, amount: confirmation.amount };
  }

  // =========================
  // STRIPE CHECKOUT SESSION (no order yet — created after payment)
  // =========================
  async createStripeCheckoutSession(params: {
    clientId: string;
    restaurantId: string;
    offerId: string;
    items: any;
    total: number;
    collectionMethod?: string;
    deliveryAddress?: string;
    deliveryPhone?: string;
    deliveryFee?: number;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
  }) {
    const verifiedTotal = await this.getVerifiedTotal(params.offerId, params.items, params.deliveryFee);

    const session = await this.stripeService.createCheckoutSession({
      orderData: {
        clientId: params.clientId,
        restaurantId: params.restaurantId,
        offerId: params.offerId,
        items: params.items,
        total: verifiedTotal,
        collectionMethod: params.collectionMethod,
        deliveryAddress: params.deliveryAddress,
        deliveryPhone: params.deliveryPhone,
        deliveryFee: params.deliveryFee,
      },
      amount: verifiedTotal,
      email: params.email,
      successUrl: params.successUrl,
      cancelUrl: params.cancelUrl,
    });

    return session;
  }

  // =========================
  // STRIPE CHECKOUT CONFIRM (poll fallback — webhook is the source of truth)
  // =========================
  async confirmStripeCheckoutSession(sessionId: string, userId: string): Promise<{
    status: string;
    orderId?: string;
    orderStatus?: string;
    amount?: number;
  }> {
    const confirmation = await this.stripeService.confirmCheckoutSession(sessionId);

    if (confirmation.status === 'paid') {
      // For checkout session fallback, we don't have orderId, so we just return status
      // The webhook will handle order creation
    } else if (confirmation.status === 'unpaid') {
      // Cannot update order status without orderId in this flow
    }

    return { status: confirmation.status };
  }

  // =========================
  // KONNECT VERIFY
  // =========================
  async verifyKonnectPayment(paymentId: string, orderId: string, userId?: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (userId && order.clientId !== userId) throw new BadRequestException('Unauthorized');

    if (order.status !== OrderStatus.PENDING) {
      return { status: 'already_processed', orderStatus: order.status };
    }

    const verification = await this.konnectService.verifyPayment(paymentId);

    if (verification.orderId && verification.orderId !== orderId) {
      throw new BadRequestException('Payment does not belong to this order');
    }

    if (verification.isSuccessful) {
      await this.updateOrderStatus(orderId, 'CONFIRMED');
    } else {
      await this.updateOrderStatus(orderId, 'CANCELLED');
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
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException('Order not found');
    if (userId && order.clientId !== userId) throw new BadRequestException('Unauthorized');

    if (order.status !== OrderStatus.PENDING) {
      return { status: 'already_processed', orderStatus: order.status };
    }

    return this._doPayPalCapture(paypalOrderId, orderId);
  }

  // Internal capture method used by both JWT and non-JWT flows
  private async _doPayPalCapture(paypalOrderId: string, orderId: string) {
    const capture = await this.paypalService.captureOrder(paypalOrderId);

    if (capture.orderId && capture.orderId !== orderId) {
      throw new BadRequestException('PayPal order does not match');
    }

    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
    });

    const existingDetails = (order.paymentDetails as Record<string, unknown>) ?? {};
    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        paymentDetails: {
          ...existingDetails,
          captureStatus: capture.status,
          capturedAmount: capture.amount,
          mode: capture.mode,
        } as any,
      },
    });

    if ((capture as { needsApproval?: boolean }).needsApproval) {
      return capture;
    }

    if (capture.isSuccessful) {
      await this.updateOrderStatus(orderId, 'CONFIRMED');
    } else {
      await this.updateOrderStatus(orderId, 'CANCELLED');
    }

    return capture;
  }

  // Public capture for PayPal redirect (no JWT required)
  async capturePayPalPaymentPublic(paypalOrderId: string, orderId: string) {
    // Verify order exists and is pending
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) throw new BadRequestException('Order not found');
    if (order.status !== 'PENDING') {
      // Already processed, return current status
      return {
        isSuccessful: order.status === 'CONFIRMED',
        status: order.status,
        alreadyProcessed: true,
      };
    }

    return this._doPayPalCapture(paypalOrderId, orderId);
  }

  // =========================
  // STRIPE WEBHOOK (source of truth — creates the order on payment)
  // =========================
  async handleStripeWebhook(rawBody: Buffer, signature: string) {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!webhookSecret) {
      throw new BadRequestException('Stripe webhook secret not configured');
    }

    let event: any;
    try {
      event = this.stripeService.constructWebhookEvent(rawBody, signature, webhookSecret);
    } catch {
      throw new BadRequestException('Invalid Stripe webhook signature');
    }

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const intent = event.data.object;
        if (intent.metadata?.orderId) {
          // Order was pre-created — just confirm it
          await this.updateOrderStatus(intent.metadata.orderId, 'CONFIRMED');
          await this.prisma.order.update({
            where: { id: intent.metadata.orderId },
            data: {
              paymentDetails: {
                stripePaymentIntentId: intent.id,
                provider: 'stripe',
              } as any,
            },
          });
        } else {
          const existing = await this.prisma.order.findFirst({
            where: { paymentDetails: { path: ['stripePaymentIntentId'], equals: intent.id } },
          });
          if (!existing) {
            await this.createOrderFromSessionMetadata(
              intent.metadata,
              intent.id,
              'stripePaymentIntentId',
            );
          }
        }
        break;
      }
      case 'checkout.session.completed': {
        const session = event.data.object;
        if (session.payment_status === 'paid') {
          const existing = await this.prisma.order.findFirst({
            where: { paymentDetails: { path: ['stripeSessionId'], equals: session.id } },
          });
          if (!existing) {
            await this.createOrderFromSessionMetadata(session.metadata, session.id);
          }
        }
        break;
      }
      default:
        this.logger.log(`Unhandled Stripe event: ${event.type}`);
    }

    return { received: true };
  }

  private async createOrderFromSessionMetadata(
    metadata: any,
    stripeRef: string,
    refKey: 'stripeSessionId' | 'stripePaymentIntentId' = 'stripeSessionId',
  ): Promise<{ id: string } | null> {
    if (!metadata?.orderData) {
      this.logger.warn(`Stripe ref ${stripeRef} missing orderData metadata`);
      return null;
    }

    let orderData: any;
    try {
      orderData = JSON.parse(metadata.orderData);
    } catch {
      this.logger.error(`Failed to parse orderData from ${stripeRef}`);
      return null;
    }

    try {
      const order = await this.ordersService.createConfirmed({
        clientId: orderData.clientId,
        restaurantId: orderData.restaurantId,
        offerId: orderData.offerId,
        items: orderData.items,
        total: orderData.total,
        collectionMethod: orderData.collectionMethod ?? 'PICKUP',
        deliveryAddress: orderData.deliveryAddress,
        deliveryPhone: orderData.deliveryPhone,
        deliveryFee: orderData.deliveryFee,
        paymentMethod: 'CARD',
        paymentDetails: { [refKey]: stripeRef, provider: 'stripe' },
      });
      this.logger.log(`Order ${order.id} created after Stripe payment ${stripeRef}`);
      return order;
    } catch (err) {
      this.logger.error(`Failed to create order from ${stripeRef}: ${err}`);
      return null;
    }
  }

  // =========================
  // PRICE VERIFICATION
  // =========================
  private async getVerifiedTotal(offerId: string, items: any, deliveryFee?: number): Promise<number> {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
      select: { discountedPrice: true, status: true },
    });
    if (!offer) throw new BadRequestException('Offer not found');
    if (offer.status !== 'ACTIVE') throw new BadRequestException('Offer is no longer available');

    let quantity = 1;
    try {
      const parsed: any = typeof items === 'string' ? JSON.parse(items) : items;
      const mainItem = Array.isArray(parsed) ? parsed[0] : parsed;
      if (typeof mainItem?.quantity === 'number') {
        quantity = Math.max(1, Math.floor(mainItem.quantity));
      }
    } catch { /* default quantity 1 */ }

    const itemsTotal = Math.round(offer.discountedPrice * quantity * 100) / 100;
    const fee = deliveryFee ?? 0;
    return Math.round((itemsTotal + fee) * 100) / 100;
  }

  // =========================
  // CORE STATUS UPDATE
  // =========================
  private async updateOrderStatus(orderId: string, orderStatus: 'CONFIRMED' | 'CANCELLED' | 'PENDING') {
    await this.prisma.order.update({
      where: { id: orderId },
      data: { status: orderStatus },
    });
  }

  // =========================
  // ORDER LOOKUP (for controllers)
  // =========================
  async getOrderById(orderId: string) {
    return this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        client: { 
          select: { email: true },
          include: { clientProfile: { select: { fullName: true } } }
        },
        restaurant: { 
          select: { email: true },
          include: { restaurantProfile: { select: { restaurantName: true } } }
        },
        offer: { select: { description: true, photoUrl: true } },
      },
    });
  }
}
