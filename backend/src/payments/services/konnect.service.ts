import { Injectable, BadRequestException, Logger } from '@nestjs/common';

@Injectable()
export class KonnectService {
  private readonly logger = new Logger(KonnectService.name);
  private konnectApiKey: string;
  private konnectBaseUrl: string;

  private konnectWalletId: string;

  constructor() {
    this.konnectApiKey = process.env.KONNECT_API_KEY || '';
    this.konnectBaseUrl =
      (process.env.KONNECT_BASE_URL || 'https://api.konnect.network/api/v2').replace(/\/$/, '');

    // Separate wallet ID from API key
    this.konnectWalletId = process.env.KONNECT_WALLET_ID || '';

    if (!this.konnectApiKey) {
      this.logger.warn('KONNECT_API_KEY not configured');
    }
    if (!this.konnectWalletId) {
      this.logger.warn('KONNECT_WALLET_ID not configured - using API key as fallback');
      this.konnectWalletId = this.konnectApiKey; // Fallback
    }
  }

  async createPayment(params: {
    orderId: string;
    amount: number;
    firstName: string;
    lastName: string;
    email: string;
    phone?: string;
    returnUrl?: string;
  }) {
    if (!this.konnectApiKey) {
      throw new BadRequestException('Konnect is not configured');
    }

    try {
      const returnUrl =
        params.returnUrl ||
        `${process.env.FRONTEND_URL || 'http://192.168.1.15:3000'}/payment-success`;

      const parsedAmount = Number(params.amount);
      if (!Number.isFinite(parsedAmount)) {
        throw new BadRequestException('Invalid order amount');
      }

      const finalAmount = Math.round(parsedAmount * 1000);
      if (!Number.isInteger(finalAmount) || finalAmount <= 0) {
        throw new BadRequestException('Amount must be a positive integer in millimes');
      }

      this.logger.log(`Creating Konnect payment for order ${params.orderId}`);
      this.logger.log(`Konnect amount: ${parsedAmount} TND (${finalAmount} millimes)`);

      // Konnect API - Correct implementation based on docs
      const requestBody = {
        receiverWalletId: this.konnectWalletId, // Wallet ID (NOT API key!)
        token: 'TND',
        amount: finalAmount,
        type: 'immediate',
        description: `Order ${params.orderId}`,
        acceptedPaymentMethods: ['wallet', 'bank_card', 'e-DINAR'],
        lifespan: 10,
        checkoutForm: true,
        addPaymentFeesToAmount: true,
        orderId: params.orderId,
        successUrl: returnUrl,
        failUrl: returnUrl,
        theme: 'light',
      };

      this.logger.debug(`Konnect request: ${JSON.stringify(requestBody)}`);

      // Correct endpoint and auth header
      const response = await fetch(`${this.konnectBaseUrl}/payments/init-payment`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.konnectApiKey,
        },
        body: JSON.stringify(requestBody),
      });

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error('Konnect error response:', errorText);
        this.logger.error('Konnect status:', response.status);
        throw new Error(`Konnect API error: ${response.status} - ${errorText}`);
      }

      const data = await response.json();

      this.logger.debug(`Konnect response: ${JSON.stringify(data)}`);

      // Konnect returns paymentRef or payUrl
      return {
        paymentUrl: data.payUrl || data.url || data.paymentUrl || data.link,
        paymentId: data.paymentRef || data.id || data.paymentId || data.ref,
      };
    } catch (error) {
      this.logger.error('Konnect payment error:', error);
      throw new BadRequestException(
        error instanceof Error ? error.message : 'Failed to create Konnect payment',
      );
    }
  }

  async verifyPayment(paymentId: string) {
    try {
      const response = await fetch(
        `${this.konnectBaseUrl}/payments/${paymentId}`,
        {
          headers: {
            'x-api-key': this.konnectApiKey,
          },
        },
      );

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error('Konnect verify error:', errorText);
        throw new Error('Failed to verify payment');
      }

      const data = await response.json();
      this.logger.log('Konnect verify response:', JSON.stringify(data));

      // Check payment status from the payment object
      const payment = data.payment || data;
      return {
        status: payment.status || payment.state,
        amount: payment.amount ? payment.amount / 1000 : 0,
        orderId: payment.orderId,
        isSuccessful: (payment.status === 'completed' || payment.state === 'completed'),
      };
    } catch (error) {
      this.logger.error('Konnect verification error:', error);
      throw new BadRequestException('Failed to verify Konnect payment');
    }
  }
}
