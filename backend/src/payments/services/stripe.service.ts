import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import Stripe from 'stripe';

@Injectable()
export class StripeService {
  private readonly logger = new Logger(StripeService.name);
  private stripe: InstanceType<typeof Stripe>;
  private stripePk: string;

  constructor() {
    const secretKey = process.env.STRIPE_SECRET_KEY || '';
    this.stripePk = process.env.STRIPE_PUBLISHABLE_KEY || '';

    if (!secretKey) {
      this.logger.warn('STRIPE_SECRET_KEY not configured');
    }

    this.stripe = new Stripe(secretKey, {
      apiVersion: '2026-03-25.dahlia',
    });
  }

  private ensureStripe() {
    if (!this.stripe) {
      throw new BadRequestException('Stripe is not configured');
    }
  }

  async createPaymentIntent(params: {
    orderId: string;
    amount: number;
    email?: string;
    description?: string;
  }) {
    this.ensureStripe();

    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: Math.round(params.amount * 100),
      currency: 'eur',
      metadata: {
        orderId: params.orderId,
        email: params.email || 'unknown',
      },
      description: params.description || `FiftyFood Order ${params.orderId}`,
    });

    return {
      clientSecret: paymentIntent.client_secret,
      publishableKey: this.stripePk,
    };
  }

  async confirmPayment(paymentIntentId: string) {
    this.ensureStripe();

    const paymentIntent =
      await this.stripe.paymentIntents.retrieve(paymentIntentId);

    return {
      status: paymentIntent.status,
      amount: paymentIntent.amount / 100,
      orderId: paymentIntent.metadata?.orderId,
    };
  }

  async createCheckoutSession(params: {
    orderId: string;
    amount: number;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
  }) {
    this.ensureStripe();

    const baseUrl =
      process.env.PUBLIC_BACKEND_URL || 'http://192.168.1.15:3000';

    const successUrl =
      params.successUrl || `${baseUrl}/payments/stripe/checkout/success`;

    const cancelUrl =
      params.cancelUrl || `${baseUrl}/payments/stripe/checkout/cancel`;

    const session = await this.stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'eur',
            unit_amount: Math.round(params.amount * 100),
            product_data: {
              name: `FiftyFood Order ${params.orderId}`,
            },
          },
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      customer_email: params.email,
      metadata: {
        orderId: params.orderId,
      },
    });

    return {
      sessionId: session.id,
      sessionUrl: session.url,
    };
  }

  async confirmCheckoutSession(sessionId: string) {
    this.ensureStripe();

    const session = await this.stripe.checkout.sessions.retrieve(sessionId);

    return {
      status: session.payment_status,
      orderId: session.metadata?.orderId,
      paymentIntentId: session.payment_intent,
    };
  }
}