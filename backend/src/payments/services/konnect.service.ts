import { Injectable, BadRequestException, Logger } from '@nestjs/common';

@Injectable()
export class KonnectService {
  private readonly logger = new Logger(KonnectService.name);
  private konnectApiKey: string;
  private konnectBaseUrl: string;

  constructor() {
    this.konnectApiKey = process.env.KONNECT_API_KEY || '';
    this.konnectBaseUrl = process.env.KONNECT_BASE_URL || 'https://api.konnect.tn';

    if (!this.konnectApiKey) {
      this.logger.warn('KONNECT_API_KEY not configured');
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
        `${process.env.FRONTEND_URL || 'http://192.168.61.154:3000'}/payment-success`;

      const response = await fetch(
        `${this.konnectBaseUrl}/api/v2/payments`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.konnectApiKey}`,
          },
          body: JSON.stringify({
            amount: Math.round(params.amount * 1000), // Konnect expects millimes (1 dinar = 1000 millimes)
            currency: 'TND',
            orderId: params.orderId,
            firstName: params.firstName,
            lastName: params.lastName,
            email: params.email,
            phone: params.phone || '',
            returnUrl,
          }),
        },
      );

      if (!response.ok) {
        const error = await response.json();
        this.logger.error('Konnect error:', error);
        throw new Error(error.message || 'Failed to create Konnect payment');
      }

      const data = await response.json();

      return {
        paymentUrl: data.payUrl || data.url,
        paymentId: data.id || data.paymentId,
      };
    } catch (error) {
      this.logger.error('Konnect payment error:', error);
      throw new BadRequestException('Failed to create Konnect payment');
    }
  }

  async verifyPayment(paymentId: string) {
    try {
      const response = await fetch(
        `${this.konnectBaseUrl}/api/v2/payments/${paymentId}`,
        {
          headers: {
            Authorization: `Bearer ${this.konnectApiKey}`,
          },
        },
      );

      if (!response.ok) {
        throw new Error('Failed to verify payment');
      }

      const data = await response.json();

      return {
        status: data.state, // 'completed', 'pending', 'failed'
        amount: data.amount / 1000, // Convert back to dinars
        orderId: data.orderId,
        isSuccessful: data.state === 'completed',
      };
    } catch (error) {
      this.logger.error('Konnect verification error:', error);
      throw new BadRequestException('Failed to verify Konnect payment');
    }
  }
}
