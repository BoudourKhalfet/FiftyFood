import { Body, Controller, Post, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { PaymentsService } from './payments.service';
import { PayPalCaptureOrderDto, PayPalCreateOrderDto } from './dto/payment.dto';

type ReqWithUser = Request & { user: JwtPayload };

@Controller('paypal')
export class PayPalController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('create-order')
  @UseGuards(JwtAuthGuard)
  async createOrder(@Req() req: ReqWithUser, @Body() dto: PayPalCreateOrderDto) {
    if (!dto.orderId) {
      throw new BadRequestException('Order ID is required');
    }

    return this.paymentsService.createPayPalPayment({
      orderId: dto.orderId,
      userId: req.user.sub,
      returnUrl: dto.returnUrl,
      cancelUrl: dto.cancelUrl,
      amount: dto.amount,
    });
  }

  @Post('capture-order')
  @UseGuards(JwtAuthGuard)
  async captureOrder(@Req() req: ReqWithUser, @Body() dto: PayPalCaptureOrderDto) {
    if (!dto.orderId || !dto.paypalOrderId) {
      throw new BadRequestException('orderId and paypalOrderId are required');
    }

    return this.paymentsService.capturePayPalPayment(dto.paypalOrderId, dto.orderId, req.user.sub);
  }
}
