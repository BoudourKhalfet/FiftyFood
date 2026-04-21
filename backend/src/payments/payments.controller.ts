import {
  Controller,
  Post,
  Body,
  Param,
  Get,
  UseGuards,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  CreateStripeIntentDto,
  CreateStripeCheckoutDto,
  CreateKonnectPaymentDto,
  CreatePayPalPaymentDto,
} from './dto/payment.dto';
import { JwtPayload } from '../auth/jwt.strategy';

type ReqWithUser = Request & { user: JwtPayload };

@Controller('payments')
export class PaymentsController {
  constructor(private paymentsService: PaymentsService) {}

  /**
   * Create Stripe payment intent
   * POST /payments/create-intent
   */
  @Post('create-intent')
  @UseGuards(JwtAuthGuard)
  async createStripeIntent(
    @Req() req: ReqWithUser,
    @Body() dto: CreateStripeIntentDto,
  ) {
    if (!dto.orderId || !dto.amount || dto.amount <= 0) {
      throw new BadRequestException('Invalid order or amount');
    }

    return this.paymentsService.createStripeIntent({
      orderId: dto.orderId,
      userId: req.user.sub,
      amount: dto.amount,
      email: dto.email,
    });
  }

  /**
   * Create Stripe Checkout session (web)
   * POST /payments/stripe/checkout
   */
  @Post('stripe/checkout')
  @UseGuards(JwtAuthGuard)
  async createStripeCheckout(
    @Req() req: ReqWithUser,
    @Body() dto: CreateStripeCheckoutDto,
  ) {
    if (!dto.orderId) {
      throw new BadRequestException('Order ID is required');
    }

    return this.paymentsService.createStripeCheckoutSession({
      orderId: dto.orderId,
      userId: req.user.sub,
      email: dto.email,
      successUrl: dto.successUrl,
      cancelUrl: dto.cancelUrl,
    });
  }

  /**
   * Create Konnect (E-Dinar) payment
   * POST /payments/konnect
   */
  @Post('konnect')
  @UseGuards(JwtAuthGuard)
  async createKonnectPayment(
    @Req() req: ReqWithUser,
    @Body() dto: CreateKonnectPaymentDto,
  ) {
    if (!dto.orderId || !dto.firstName || !dto.lastName || !dto.email) {
      throw new BadRequestException('Missing required fields');
    }

    return this.paymentsService.createKonnectPayment({
      orderId: dto.orderId,
      userId: req.user.sub,
      firstName: dto.firstName,
      lastName: dto.lastName,
      email: dto.email,
      phone: dto.phone,
    });
  }

  /**
   * Create PayPal payment
   * POST /payments/paypal
   */
  @Post('paypal')
  @UseGuards(JwtAuthGuard)
  async createPayPalPayment(
    @Req() req: ReqWithUser,
    @Body() dto: CreatePayPalPaymentDto,
  ) {
    if (!dto.orderId) {
      throw new BadRequestException('Order ID is required');
    }

    return this.paymentsService.createPayPalPayment({
      orderId: dto.orderId,
      userId: req.user.sub,
      amount: dto.amount,
      returnUrl: dto.returnUrl,
      cancelUrl: dto.cancelUrl,
    });
  }

  /**
   * Verify Konnect payment status
   * GET /payments/konnect/:paymentId/verify/:orderId
   */
  @Get('konnect/:paymentId/verify/:orderId')
  async verifyKonnectPayment(
    @Param('paymentId') paymentId: string,
    @Param('orderId') orderId: string,
  ) {
    return this.paymentsService.verifyKonnectPayment(paymentId, orderId);
  }

  /**
   * Capture PayPal payment
   * POST /payments/paypal/:paypalOrderId/capture/:orderId
   */
  @Post('paypal/:paypalOrderId/capture/:orderId')
  @UseGuards(JwtAuthGuard)
  async capturePayPalPayment(
    @Req() req: ReqWithUser,
    @Param('paypalOrderId') paypalOrderId: string,
    @Param('orderId') orderId: string,
  ) {
    return this.paymentsService.capturePayPalPayment(
      paypalOrderId,
      orderId,
      req.user.sub,
    );
  }

  /**
   * Confirm Stripe payment
   * POST /payments/confirm-stripe/:orderId/:paymentIntentId
   */
  @Post('confirm-stripe/:orderId/:paymentIntentId')
  async confirmStripePayment(
    @Param('orderId') orderId: string,
    @Param('paymentIntentId') paymentIntentId: string,
  ) {
    return this.paymentsService.confirmStripePayment(orderId, paymentIntentId);
  }

  /**
   * Confirm Stripe Checkout session (web)
   * GET /payments/stripe/checkout/:sessionId/confirm/:orderId
   */
  @Get('stripe/checkout/:sessionId/confirm/:orderId')
  async confirmStripeCheckout(
    @Param('sessionId') sessionId: string,
    @Param('orderId') orderId: string,
  ) {
    return this.paymentsService.confirmStripeCheckoutSession(sessionId, orderId);
  }
}
