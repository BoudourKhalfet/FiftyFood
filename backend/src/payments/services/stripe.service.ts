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

<<<<<<< HEAD
    this.stripe = new Stripe(secretKey, {
      apiVersion: '2026-04-22.dahlia',
    });
=======
    this.stripe = new Stripe(secretKey);
>>>>>>> e4c0d50e25f43f81c5edf5b91e096c9f90e51860
  }

  private ensureStripe() {
    if (!this.stripe) {
      throw new BadRequestException('Stripe is not configured');
    }
  }

  async createPaymentIntent(params: {
    orderData: Record<string, any>;
    amount: number;
    email?: string;
  }) {
    this.ensureStripe();

    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: Math.round(params.amount * 100),
      currency: 'eur',
      metadata: {
        orderData: JSON.stringify(params.orderData),
      },
      description: 'FiftyFood Order',
      receipt_email: params.email || undefined,
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
      metadata: paymentIntent.metadata,
    };
  }

  async createCheckoutSession(params: {
    orderData: Record<string, any>;
    amount: number;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
  }) {
    this.ensureStripe();

    const baseUrl = process.env.PUBLIC_BACKEND_URL;
    if (!baseUrl) {
      throw new BadRequestException('PUBLIC_BACKEND_URL is not configured');
    }

    const successUrl =
      params.successUrl || `${baseUrl}/payments/stripe/checkout/success`;

    const cancelUrl =
      params.cancelUrl || `${baseUrl}/payments/stripe/checkout/cancel`;

    // Only set customer_email if valid
    const sessionConfig: any = {
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'eur',
            unit_amount: Math.round(params.amount * 100),
            product_data: {
              name: `FiftyFood Order`,
            },
          },
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
<<<<<<< HEAD
      ...(params.email ? { customer_email: params.email } : {}),
=======
>>>>>>> e4c0d50e25f43f81c5edf5b91e096c9f90e51860
      metadata: {
        orderData: JSON.stringify(params.orderData),
      },
    };

    // Only add customer_email if it's a valid non-empty string
    if (params.email && params.email.trim().length > 0 && params.email.includes('@')) {
      sessionConfig.customer_email = params.email.trim();
    }

    const session = await this.stripe.checkout.sessions.create(sessionConfig);

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
      metadata: session.metadata,
    };
  }

  constructWebhookEvent(rawBody: Buffer, signature: string, secret: string) {
    return this.stripe.webhooks.constructEvent(rawBody, signature, secret);
  }
}
