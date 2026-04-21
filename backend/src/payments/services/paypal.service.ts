import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as paypal from '@paypal/checkout-server-sdk';

@Injectable()
export class PayPalService {
  private readonly logger = new Logger(PayPalService.name);
  private paypalClientId: string;
  private paypalClientSecret: string;
  private mode: 'sandbox' | 'live';
  private client: paypal.core.PayPalHttpClient | null;

  constructor() {
    this.paypalClientId = process.env.PAYPAL_CLIENT_ID || '';
    this.paypalClientSecret =
      process.env.PAYPAL_CLIENT_SECRET || process.env.PAYPAL_SECRET || '';
    this.mode =
      process.env.PAYPAL_MODE?.toLowerCase() === 'live' ? 'live' : 'sandbox';
    this.client = null;

    if (!this.paypalClientId || !this.paypalClientSecret) {
      this.logger.warn('PayPal credentials not configured');
      return;
    }

    const environment =
      this.mode === 'live'
        ? new paypal.core.LiveEnvironment(
            this.paypalClientId,
            this.paypalClientSecret,
          )
        : new paypal.core.SandboxEnvironment(
            this.paypalClientId,
            this.paypalClientSecret,
          );

    this.client = new paypal.core.PayPalHttpClient(environment);
  }

  private ensureClient(): paypal.core.PayPalHttpClient {
    if (!this.client) {
      throw new BadRequestException('PayPal is not configured');
    }
    return this.client;
  }

  async createOrder(params: {
    orderId: string;
    amount: number;
    description?: string;
    returnUrl?: string;
    cancelUrl?: string;
  }) {
    try {
      const request = new paypal.orders.OrdersCreateRequest();
      request.prefer('return=representation');
      request.requestBody({
        intent: 'CAPTURE',
        purchase_units: [
          {
            reference_id: params.orderId,
            amount: {
              currency_code: 'EUR',
              value: params.amount.toFixed(2),
            },
            description:
              params.description || `FiftyFood Order ${params.orderId}`,
          },
        ],
        application_context: {
          return_url:
            params.returnUrl ||
            `${process.env.FRONTEND_URL || 'http://localhost:3000'}/payment-success`,
          cancel_url:
            params.cancelUrl ||
            `${process.env.FRONTEND_URL || 'http://localhost:3000'}/payment-cancel`,
          user_action: 'PAY_NOW',
        },
      });

      const response = await this.ensureClient().execute(request);
      const data = response.result as {
        id: string;
        links?: Array<{ rel?: string; href?: string }>;
      };

      // Find the approval link
      const approvalLink = data.links?.find(
        (link) => link.rel === 'approve',
      );

      return {
        paypalOrderId: data.id,
        approvalUrl: approvalLink?.href,
        mode: this.mode,
      };
    } catch (error) {
      this.logger.error('PayPal order error:', error);
      throw new BadRequestException('Failed to create PayPal order');
    }
  }

  async captureOrder(paypalOrderId: string) {
    try {
      const request = new paypal.orders.OrdersCaptureRequest(paypalOrderId);
      request.requestBody({} as any);

      const response = await this.ensureClient().execute(request);
      const data = response.result as {
        id: string;
        status: string;
        purchase_units?: Array<{
          reference_id?: string;
          amount?: { value?: string };
        }>;
      };

      // Check if payment was successful
      const isSuccessful = data.status === 'COMPLETED';
      const orderId =
        data.purchase_units?.[0]?.reference_id;
      const amount = data.purchase_units?.[0]?.amount?.value;

      return {
        status: data.status,
        isSuccessful,
        amount: Number.parseFloat(amount ?? '0'),
        orderId,
        paypalOrderId: data.id,
        mode: this.mode,
      };
    } catch (error) {
      this.logger.error('PayPal capture error:', error);
      throw new BadRequestException('Failed to capture PayPal payment');
    }
  }
}
