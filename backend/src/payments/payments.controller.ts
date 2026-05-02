import {
  Controller,
  Post,
  Body,
  Param,
  Get,
  UseGuards,
  Req,
  Headers,
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
  constructor(private readonly paymentsService: PaymentsService) {}

  // =========================
  // STRIPE INTENT
  // =========================
  @Post('create-intent')
  @UseGuards(JwtAuthGuard)
  async createStripeIntent(
    @Req() req: ReqWithUser,
    @Body() dto: CreateStripeIntentDto,
  ) {
    return this.paymentsService.createStripeIntent({
      clientId: req.user.sub,
      restaurantId: dto.restaurantId,
      offerId: dto.offerId,
      items: dto.items,
      total: dto.total,
      collectionMethod: dto.collectionMethod,
      deliveryAddress: dto.deliveryAddress,
      deliveryPhone: dto.deliveryPhone,
      deliveryFee: dto.deliveryFee,
      email: dto.email,
    });
  }

  // =========================
  // STRIPE CHECKOUT
  // =========================
  @Post('stripe/checkout')
  @UseGuards(JwtAuthGuard)
  async createStripeCheckout(
    @Req() req: ReqWithUser,
    @Body() dto: CreateStripeCheckoutDto,
  ) {
    return this.paymentsService.createStripeCheckoutSession({
      clientId: req.user.sub,
      restaurantId: dto.restaurantId,
      offerId: dto.offerId,
      items: dto.items,
      total: dto.total,
      collectionMethod: dto.collectionMethod,
      deliveryAddress: dto.deliveryAddress,
      deliveryPhone: dto.deliveryPhone,
      deliveryFee: dto.deliveryFee,
      email: dto.email,
      successUrl: dto.successUrl,
      cancelUrl: dto.cancelUrl,
    });
  }

  // =========================
  // KONNECT PAYMENT
  // =========================
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

  // =========================
  // PAYPAL PAYMENT
  // =========================
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

  // =========================
  // KONNECT VERIFY
  // =========================
  @Get('konnect/:paymentId/verify/:orderId')
  @UseGuards(JwtAuthGuard)
  async verifyKonnectPayment(
    @Req() req: ReqWithUser,
    @Param('paymentId') paymentId: string,
    @Param('orderId') orderId: string,
  ) {
    return this.paymentsService.verifyKonnectPayment(paymentId, orderId, req.user.sub);
  }

  // =========================
  // PAYPAL CAPTURE
  // =========================
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

  // =========================
  // STRIPE CONFIRM INTENT
  // =========================
  @Post('confirm-stripe/:paymentIntentId')
  @UseGuards(JwtAuthGuard)
  async confirmStripePayment(
    @Req() req: ReqWithUser,
    @Param('paymentIntentId') paymentIntentId: string,
  ) {
    return this.paymentsService.confirmStripePayment(paymentIntentId, req.user.sub);
  }

  // =========================
  // STRIPE WEBHOOK
  // =========================
  @Post('webhooks/stripe')
  async stripeWebhook(
    @Req() req: Request & { body: Buffer },
    @Headers('stripe-signature') signature: string,
  ) {
    if (!signature) {
      throw new BadRequestException('Missing stripe-signature header');
    }
    return this.paymentsService.handleStripeWebhook(req.body, signature);
  }

  // =========================
  // STRIPE CHECKOUT CONFIRM
  // =========================
  @Get('stripe/checkout/:sessionId/confirm')
  @UseGuards(JwtAuthGuard)
  async confirmStripeCheckout(
    @Req() req: ReqWithUser,
    @Param('sessionId') sessionId: string,
  ) {
    return this.paymentsService.confirmStripeCheckoutSession(
      sessionId,
      req.user.sub,
    );
  }
}
