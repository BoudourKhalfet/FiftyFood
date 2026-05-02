import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as paypal from '@paypal/checkout-server-sdk';

@Injectable()
export class PayPalService {
  private readonly logger = new Logger(PayPalService.name);
  private paypalClientId: string;
  private paypalClientSecret: string;
  private mode: 'sandbox' | 'live';
  private currencyCode: string;
  private client: paypal.core.PayPalHttpClient | null;

  constructor() {
    this.paypalClientId = process.env.PAYPAL_CLIENT_ID || '';
    this.paypalClientSecret =
      process.env.PAYPAL_CLIENT_SECRET || process.env.PAYPAL_SECRET || '';
    this.mode =
      process.env.PAYPAL_MODE?.toLowerCase() === 'live' ? 'live' : 'sandbox';
    this.currencyCode = (process.env.PAYPAL_CURRENCY || 'USD').toUpperCase();
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
    this.logger.log(
      `PayPal client initialized (mode=${this.mode}, currency=${this.currencyCode})`,
    );
  }

  private formatPayPalError(error: unknown): {
    message: string;
    issue?: string;
    debugId?: string;
    statusCode?: number;
  } {
    const fallback = { message: 'PayPal request failed' };

    if (!error || typeof error !== 'object') {
      return fallback;
    }

    const err = error as {
      statusCode?: number;
      headers?: Record<string, string>;
      _originalError?: { text?: string };
      message?: string;
    };

    let parsed: any;
    const rawText = err._originalError?.text;
    if (rawText) {
      try {
        parsed = JSON.parse(rawText);
      } catch {
        parsed = undefined;
      }
    }

    const issue = parsed?.details?.[0]?.issue as string | undefined;
    const description = parsed?.details?.[0]?.description as string | undefined;
    const debugId =
      (parsed?.debug_id as string | undefined) ||
      err.headers?.['paypal-debug-id'];

    return {
      message: description || parsed?.message || err.message || fallback.message,
      issue,
      debugId,
      statusCode: err.statusCode,
    };
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
              currency_code: this.currencyCode,
              value: Number(params.amount).toFixed(2),
            },
            description:
              params.description || `FiftyFood Order ${params.orderId}`,
          },
        ],
          application_context: {
    return_url: params.returnUrl?.startsWith('fiftyfood://')
      ? `${process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000'}/payments/paypal/success?returnUrl=${encodeURIComponent(params.returnUrl)}`
      : (params.returnUrl || `${process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000'}/payments/paypal/success`),
    cancel_url: params.cancelUrl?.startsWith('fiftyfood://')
      ? `${process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000'}/payments/paypal/cancel?cancelUrl=${encodeURIComponent(params.cancelUrl)}`
      : (params.cancelUrl || `${process.env.PUBLIC_BACKEND_URL || 'http://localhost:3000'}/payments/paypal/cancel`),
    user_action: 'PAY_NOW',
  },
      });

      const response = await this.ensureClient().execute(request);
      const data = response.result as {
        id: string;
        links?: Array<{ rel?: string; href?: string }>;
      };

      // Find the approval link
const approvalLink =
  data.links?.find((link) => link.rel === 'approve') ||
  data.links?.find((link) => link.href?.includes('checkoutnow'));

      return {
        paypalOrderId: data.id,
        approvalUrl: approvalLink?.href,
        mode: this.mode,
      };
    } catch (error) {
      const details = this.formatPayPalError(error);
      this.logger.error(
        `PayPal order error: status=${details.statusCode ?? 'unknown'} issue=${details.issue ?? 'unknown'} debugId=${details.debugId ?? 'n/a'} message=${details.message}`,
      );

      throw new BadRequestException({
        message: 'Failed to create PayPal order',
        paypalIssue: details.issue,
        paypalMessage: details.message,
        paypalDebugId: details.debugId,
      });
    }
  }

  async captureOrder(paypalOrderId: string) {
    try {
      const request = new paypal.orders.OrdersCaptureRequest(paypalOrderId);

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
      const details = this.formatPayPalError(error);

      if (details.issue === 'ORDER_NOT_APPROVED') {
        this.logger.warn(
          `PayPal capture skipped because the order is not approved yet: paypalOrderId=${paypalOrderId} debugId=${details.debugId ?? 'n/a'}`,
        );

        return {
          status: 'ORDER_NOT_APPROVED',
          isSuccessful: false,
          amount: 0,
          orderId: undefined,
          paypalOrderId,
          mode: this.mode,
          needsApproval: true,
        };
      }

      this.logger.error(
        `PayPal capture error: status=${details.statusCode ?? 'unknown'} issue=${details.issue ?? 'unknown'} debugId=${details.debugId ?? 'n/a'} message=${details.message}`,
      );

      throw new BadRequestException({
        message: 'Failed to capture PayPal payment',
        paypalIssue: details.issue,
        paypalMessage: details.message,
        paypalDebugId: details.debugId,
      });
    }
  }
}
