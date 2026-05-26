import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from './services/stripe.service';
import { KonnectService } from './services/konnect.service';
import { PayPalService } from './services/paypal.service';
import { OrderStatus } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private prisma: PrismaService,
    private stripeService: StripeService,
    private konnectService: KonnectService,
    private paypalService: PayPalService,
    private notificationsService: NotificationsService,
  ) {}

  private async findAndAuthorizeOrder(orderId: string, userId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new BadRequestException('Order not found');
    if (order.clientId !== userId)
      throw new BadRequestException('Unauthorized');
    return order;
  }

  // =========================
  // STRIPE PAYMENT INTENT (no order created yet — created by webhook on success)
  // =========================
  async createStripeIntent(params: {
    clientId: string;
    restaurantId: string;
    offerId: string;
    items: unknown[];
    total: number;
    collectionMethod?: string;
    deliveryAddress?: string;
    deliveryPhone?: string;
    deliveryFee?: number;
    email?: string;
    orderId?: string;
  }) {
    const verifiedTotal = await this.getVerifiedTotal(
      params.offerId,
      params.items,
      params.deliveryFee,
    );

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
    const order = await this.findAndAuthorizeOrder(
      params.orderId,
      params.userId,
    );

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
    const order = await this.findAndAuthorizeOrder(
      params.orderId,
      params.userId,
    );

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
  async confirmStripePayment(
    paymentIntentId: string,
    userId: string,
  ): Promise<{
    status: string;
    orderId?: string;
    orderStatus?: string;
    amount?: number;
  }> {
    const confirmation =
      await this.stripeService.confirmPayment(paymentIntentId);
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
        return {
          status: confirmation.status,
          orderId,
          amount: confirmation.amount,
        };
      }
    }

    return { status: confirmation.status, amount: confirmation.amount };
  }

  // =========================
  // STRIPE CHECKOUT SESSION
  // =========================
  async createStripeCheckoutSession(params: {
    clientId: string;
    restaurantId: string;
    offerId: string;
    items: unknown[];
    total: number;
    collectionMethod?: string;
    deliveryAddress?: string;
    deliveryPhone?: string;
    deliveryFee?: number;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
    orderId?: string;
  }) {
    const verifiedTotal = await this.getVerifiedTotal(
      params.offerId,
      params.items,
      params.deliveryFee,
    );

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
        orderId: params.orderId,
      },
      amount: verifiedTotal,
      email: params.email,
      successUrl: params.successUrl,
      cancelUrl: params.cancelUrl,
      orderId: params.orderId,
    });

    return session;
  }

  // =========================
  // STRIPE CHECKOUT CONFIRM (poll fallback — webhook is the source of truth)
  // =========================
  async confirmStripeCheckoutSession(sessionId: string): Promise<{
    status: string;
    orderId?: string;
    orderStatus?: string;
    amount?: number;
  }> {
    const confirmation =
      await this.stripeService.confirmCheckoutSession(sessionId);

    if (confirmation.status === 'paid') {
      let order = null;

      // First: try to find order by ID from metadata (if pre-created)
      if (confirmation.metadata?.orderId) {
        order = await this.prisma.order.findUnique({
          where: { id: confirmation.metadata.orderId },
        });
      }

      // Second: try to find by stripeSessionId in paymentDetails (webhook created)
      if (!order) {
        order = await this.prisma.order.findFirst({
          where: {
            paymentDetails: { path: ['stripeSessionId'], equals: sessionId },
          },
        });
      }

      if (order) {
        // If order is not confirmed yet, confirm it now (webhook might have missed it)
        if (order.status !== 'CONFIRMED') {
          this.logger.log(`Confirming order ${order.id} via Stripe polling`);
          try {
            await this.updateOrderStatus(order.id, 'CONFIRMED');
          } catch (err) {
            this.logger.error(`Failed to confirm order ${order.id}: ${err}`);
            return {
              status: 'error',
              orderId: order.id,
              orderStatus: order.status,
            };
          }
          // Refresh order to get updated status
          const refreshed = await this.prisma.order.findUnique({
            where: { id: order.id },
          });
          return {
            status: 'paid',
            orderId: order.id,
            orderStatus: refreshed?.status ?? 'CONFIRMED',
            amount: confirmation.amount,
          };
        }
        return {
          status: 'paid',
          orderId: order.id,
          orderStatus: order.status,
          amount: confirmation.amount,
        };
      }

      // Payment succeeded but order not found/created
      this.logger.warn(
        `Stripe payment paid but order not found for session ${sessionId}`,
      );
      return { status: 'order_not_found' };
    }

    return { status: confirmation.status };
  }

  // =========================
  // KONNECT VERIFY
  // =========================
  async verifyKonnectPayment(
    paymentId: string,
    orderId: string,
    userId?: string,
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new BadRequestException('Order not found');
    if (userId && order.clientId !== userId)
      throw new BadRequestException('Unauthorized');

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
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) throw new BadRequestException('Order not found');
    if (userId && order.clientId !== userId)
      throw new BadRequestException('Unauthorized');

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

    const existingDetails =
      (order.paymentDetails as Record<string, unknown>) ?? {};
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
      // Decrement offer quantity when payment is successful
      let quantityOrdered = 1;
      try {
        const parsed: any =
          typeof order.items === 'string'
            ? JSON.parse(order.items)
            : order.items;
        const mainItem = Array.isArray(parsed) ? parsed[0] : parsed;
        if (typeof mainItem?.quantity === 'number') {
          quantityOrdered = Math.max(1, Math.floor(mainItem.quantity));
        }
      } catch {
        /* default quantity 1 */
      }

      await this.prisma.$transaction(async (tx) => {
        // Decrement offer quantity
        const reserved = await tx.offer.updateMany({
          where: {
            id: order.offerId,
            status: 'ACTIVE',
            quantity: { gte: quantityOrdered },
          },
          data: { quantity: { decrement: quantityOrdered } },
        });
        if (reserved.count === 0) {
          throw new BadRequestException('Offer no longer available');
        }
        // Update order status
        await tx.order.update({
          where: { id: orderId },
          data: { status: 'CONFIRMED' },
        });
        // Mark as sold out if quantity reaches 0
        await tx.offer.updateMany({
          where: { id: order.offerId, quantity: { lte: 0 } },
          data: { status: 'SOLD_OUT' },
        });
      });
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
      event = this.stripeService.constructWebhookEvent(
        rawBody,
        signature,
        webhookSecret,
      );
    } catch {
      throw new BadRequestException('Invalid Stripe webhook signature');
    }

    this.logger.log(`Stripe webhook received: ${event.type}`);

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const intent = event.data.object;
        if (intent.metadata?.orderId) {
          // Order was pre-created — just confirm it
          this.logger.log(
            `Order ${intent.metadata.orderId} confirmed via Stripe webhook (payment_intent)`,
          );
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
          this.logger.warn(
            `Stripe webhook: No orderId in payment_intent ${intent.id}`,
          );
        }
        break;
      }
      case 'checkout.session.completed': {
        const session = event.data.object;
        this.logger.log(
          `checkout.session.completed: payment_status=${session.payment_status}, metadata.orderId=${session.metadata?.orderId}`,
        );
        if (session.payment_status === 'paid') {
          // First: check if order was pre-created by orderId from metadata
          let order = null;
          if (session.metadata?.orderId) {
            order = await this.prisma.order.findUnique({
              where: { id: session.metadata.orderId },
            });
            this.logger.log(
              `Found order by metadata.orderId: ${order ? order.id : 'null'}`,
            );
          }

          // Second: check by stripeSessionId in paymentDetails
          if (!order) {
            order = await this.prisma.order.findFirst({
              where: {
                paymentDetails: {
                  path: ['stripeSessionId'],
                  equals: session.id,
                },
              },
            });
            this.logger.log(
              `Found order by stripeSessionId: ${order ? order.id : 'null'}`,
            );
          }

          if (!order) {
            // No existing order found - this shouldn't happen with new flow
            this.logger.warn(
              `Stripe webhook: No order found for session ${session.id}`,
            );
          } else if (order.status !== 'CONFIRMED') {
            // Order exists but not confirmed - confirm it (will decrement quantity and send notification)
            this.logger.log(
              `Order ${order.id} confirmed via Stripe webhook (checkout.session)`,
            );
            await this.updateOrderStatus(order.id, 'CONFIRMED');
            // Update payment details separately
            await this.prisma.order.update({
              where: { id: order.id },
              data: {
                paymentDetails: {
                  ...(order.paymentDetails as object),
                  stripeSessionId: session.id,
                  provider: 'stripe',
                } as any,
              },
            });
          }
        }
        break;
      }
      default:
        this.logger.log(`Unhandled Stripe event: ${event.type}`);
    }

    return { received: true };
  }

  // =========================
  // PRICE VERIFICATION
  // =========================
  private async getVerifiedTotal(
    offerId: string,
    items: any,
    deliveryFee?: number,
  ): Promise<number> {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
      select: { discountedPrice: true, status: true },
    });
    if (!offer) throw new BadRequestException('Offer not found');
    if (offer.status !== 'ACTIVE')
      throw new BadRequestException('Offer is no longer available');

    let quantity = 1;
    try {
      const parsed: any = typeof items === 'string' ? JSON.parse(items) : items;
      const mainItem = Array.isArray(parsed) ? parsed[0] : parsed;
      if (typeof mainItem?.quantity === 'number') {
        quantity = Math.max(1, Math.floor(mainItem.quantity));
      }
    } catch {
      /* default quantity 1 */
    }

    const itemsTotal = Math.round(offer.discountedPrice * quantity * 100) / 100;
    const fee = deliveryFee ?? 0;
    return Math.round((itemsTotal + fee) * 100) / 100;
  }

  // =========================
  // CORE STATUS UPDATE
  // =========================
  private async updateOrderStatus(
    orderId: string,
    orderStatus: 'CONFIRMED' | 'CANCELLED' | 'PENDING',
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) return;

    // Only update if status is actually changing
    if (order.status === orderStatus) return;

    // When confirming, decrement offer quantity first
    if (orderStatus === 'CONFIRMED') {
      let quantityOrdered = 1;
      try {
        const parsed: any =
          typeof order.items === 'string'
            ? JSON.parse(order.items)
            : order.items;
        const mainItem = Array.isArray(parsed) ? parsed[0] : parsed;
        if (typeof mainItem?.quantity === 'number') {
          quantityOrdered = Math.max(1, Math.floor(mainItem.quantity));
        }
      } catch {
        /* default quantity 1 */
      }

      this.logger.log(
        `Decrementing offer ${order.offerId} quantity by ${quantityOrdered}`,
      );
      await this.prisma.$transaction(async (tx) => {
        // Decrement offer quantity
        const reserved = await tx.offer.updateMany({
          where: {
            id: order.offerId,
            status: 'ACTIVE',
            quantity: { gte: quantityOrdered },
          },
          data: { quantity: { decrement: quantityOrdered } },
        });
        if (reserved.count === 0) {
          throw new BadRequestException('Offer no longer available');
        }
        this.logger.log(
          `Offer ${order.offerId} quantity decremented by ${quantityOrdered}`,
        );
        // Update order status
        await tx.order.update({
          where: { id: orderId },
          data: { status: 'CONFIRMED' },
        });
        // Mark as sold out if quantity reaches 0
        const soldOut = await tx.offer.updateMany({
          where: { id: order.offerId, quantity: { lte: 0 } },
          data: { status: 'SOLD_OUT' },
        });
        if (soldOut.count > 0) {
          this.logger.log(`Offer ${order.offerId} marked as SOLD_OUT`);
        }
      });

      this.logger.log(`Order ${orderId} confirmed - sending notification`);
      void this.notificationsService.notifyOrderCreated(orderId);
    } else {
      await this.prisma.order.update({
        where: { id: orderId },
        data: { status: orderStatus },
      });
    }
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
          include: { clientProfile: { select: { fullName: true } } },
        },
        restaurant: {
          select: { email: true },
          include: { restaurantProfile: { select: { restaurantName: true } } },
        },
        offer: { select: { description: true, photoUrl: true } },
      },
    });
  }
}
