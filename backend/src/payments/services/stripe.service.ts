import { Injectable, BadRequestException, Logger } from '@nestjs/common';

@Injectable()
export class StripeService {
  private readonly logger = new Logger(StripeService.name);
  private stripeSecretKey: string;
  private stripePk: string;

  constructor() {
    this.stripeSecretKey = process.env.STRIPE_SECRET_KEY || '';
    this.stripePk = process.env.STRIPE_PUBLISHABLE_KEY || '';

    if (!this.stripeSecretKey) {
      this.logger.warn('STRIPE_SECRET_KEY not configured');
    }
  }

  async createPaymentIntent(params: {
    orderId: string;
    amount: number;
    email?: string;
    description?: string;
  }) {
    if (!this.stripeSecretKey) {
      throw new BadRequestException('Stripe is not configured');
    }

    try {
      // Using dynamic import to avoid requiring stripe at module load
      const Stripe = require('stripe');
      const stripe = new Stripe(this.stripeSecretKey);

      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(params.amount * 100), // Convert to cents
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
    } catch (error) {
      this.logger.error('Stripe payment intent error:', error);
      throw new BadRequestException('Failed to create Stripe payment intent');
    }
  }

  async confirmPayment(paymentIntentId: string) {
    try {
      const Stripe = require('stripe');
      const stripe = new Stripe(this.stripeSecretKey);

      const paymentIntent = await stripe.paymentIntents.retrieve(
        paymentIntentId,
      );

      return {
        status: paymentIntent.status,
        amount: paymentIntent.amount / 100,
        orderId: paymentIntent.metadata?.orderId,
      };
    } catch (error) {
      this.logger.error('Stripe confirmation error:', error);
      throw new BadRequestException('Failed to confirm Stripe payment');
    }
  }

  async createCheckoutSession(params: {
    orderId: string;
    amount: number;
    email?: string;
    successUrl?: string;
    cancelUrl?: string;
  }) {
    if (!this.stripeSecretKey) {
      throw new BadRequestException('Stripe is not configured');
    }

    try {
      const Stripe = require('stripe');
      const stripe = new Stripe(this.stripeSecretKey);

      const baseUrl =
        process.env.PUBLIC_BACKEND_URL || 'http://192.168.61.154:3000';
      const successUrl =
        params.successUrl || `${baseUrl}/payments/stripe/checkout/success`;
      const cancelUrl =
        params.cancelUrl || `${baseUrl}/payments/stripe/checkout/cancel`;

      const session = await stripe.checkout.sessions.create({
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
        customer_email: params.email || undefined,
        metadata: {
          orderId: params.orderId,
        },
      });

      return {
        sessionId: session.id,
        sessionUrl: session.url,
      };
    } catch (error) {
      this.logger.error('Stripe checkout session error:', error);
      throw new BadRequestException('Failed to create Stripe checkout session');
    }
  }

  async confirmCheckoutSession(sessionId: string) {
    try {
      const Stripe = require('stripe');
      const stripe = new Stripe(this.stripeSecretKey);

      const session = await stripe.checkout.sessions.retrieve(sessionId);
      return {
        status: session.payment_status,
        orderId: session.metadata?.orderId,
        paymentIntentId: session.payment_intent,
      };
    } catch (error) {
      this.logger.error('Stripe checkout confirm error:', error);
      throw new BadRequestException('Failed to confirm Stripe checkout session');
    }
  }
}
