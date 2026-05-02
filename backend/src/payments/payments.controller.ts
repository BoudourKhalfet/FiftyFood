import {
  Controller,
  Post,
  Body,
  Param,
  Get,
  UseGuards,
  Req,
<<<<<<< HEAD
  Headers,
=======
  Res,
>>>>>>> e4c0d50e25f43f81c5edf5b91e096c9f90e51860
  BadRequestException,
} from '@nestjs/common';
import { Request } from 'express';
import { Response } from 'express';
import { PaymentsService } from './payments.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Public } from '../auth/decorators/public.decorator';
import {
  CreateStripeIntentDto,
  CreateStripeCheckoutDto,
  CreateKonnectPaymentDto,
  CreatePayPalPaymentDto,
} from './dto/payment.dto';
import { JwtPayload } from '../auth/jwt.strategy';

type ReqWithUser = Request & { user: JwtPayload };

function renderPayPalReturnPage(title: string, message: string) {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f7f7f7; color: #1f2937; }
      .card { max-width: 520px; margin: 24px; padding: 28px; background: #fff; border: 1px solid #e5e7eb; border-radius: 16px; box-shadow: 0 8px 30px rgba(0,0,0,.06); text-align: center; }
      h1 { margin: 0 0 12px; font-size: 24px; }
      p { margin: 0; line-height: 1.6; }
      .subtle { margin-top: 16px; color: #6b7280; font-size: 14px; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>${title}</h1>
      <p>${message}</p>
      <p class="subtle">You can close this tab and return to the app.</p>
    </div>
  </body>
</html>`;
}

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
<<<<<<< HEAD
  @Post('confirm-stripe/:paymentIntentId')
  @UseGuards(JwtAuthGuard)
  async confirmStripePayment(
    @Req() req: ReqWithUser,
=======
  @Post('confirm-stripe/:orderId/:paymentIntentId')
  @UseGuards(JwtAuthGuard)
  async confirmStripePayment(
    @Req() req: ReqWithUser,
    @Param('orderId') orderId: string,
>>>>>>> e4c0d50e25f43f81c5edf5b91e096c9f90e51860
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
<<<<<<< HEAD
}
=======

  // =========================
  // PAYPAL RETURN PAGES
  // =========================
  @Public()
  @Get('paypal/success')
  async paypalSuccess(@Req() req: Request, @Res() res: Response) {
    try {
      const paypalOrderId = req.query.token as string;
      const orderId = req.query.orderId as string;

      if (!paypalOrderId || !orderId) {
        throw new BadRequestException('Missing parameters');
      }

      // Use public capture - no JWT required for PayPal redirect
      await this.paymentsService.capturePayPalPaymentPublic(
        paypalOrderId,
        orderId,
      );

      // Check if returnUrl is a deep link (for mobile apps)
      const returnUrl = req.query.returnUrl as string;
      if (returnUrl && returnUrl.startsWith('fiftyfood://')) {
        return res.redirect(returnUrl);
      }
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
      return res.redirect(
        `${frontendUrl}/payment-success`,
      );
    } catch (error) {
      // Check if returnUrl is a deep link (for mobile apps)
      const returnUrl = req.query.returnUrl as string;
      if (returnUrl && returnUrl.startsWith('fiftyfood://')) {
        return res.redirect(returnUrl);
      }
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
      // If already captured, still redirect to success
      if ((error as Error).message?.includes('ALREADY_CAPTURED') ||
          (error as Error).message?.includes('DUPLICATE_CAPTURE')) {
        return res.redirect(
          `${frontendUrl}/payment-success`,
        );
      }
      return res.redirect(
        `${frontendUrl}/payment-error`,
      );
    }
  }

  @Get('paypal/cancel')
  async paypalCancel(@Req() req: Request, @Res() res: Response) {
    // Check if cancelUrl is a deep link (for mobile apps)
    const cancelUrl = req.query.cancelUrl as string;
    if (cancelUrl && cancelUrl.startsWith('fiftyfood://')) {
      return res.redirect(cancelUrl);
    }
    return res
      .status(200)
      .type('html')
      .send(
        renderPayPalReturnPage(
          'PayPal payment cancelled',
          'The payment was cancelled or not completed.',
        ),
      );
  }
}
>>>>>>> e4c0d50e25f43f81c5edf5b91e096c9f90e51860
