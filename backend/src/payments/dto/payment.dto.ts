import { IsString, IsNumber, IsEnum, IsOptional } from 'class-validator';

export enum PaymentMethod {
  CARD = 'CARD',
  EDINAR = 'EDINAR',
  PAYPAL = 'PAYPAL',
}

export class CreatePaymentIntentDto {
  @IsString()
  orderId!: string;

  @IsNumber()
  amount!: number;

  @IsString()
  @IsOptional()
  description?: string;
}

export class CreateStripeIntentDto extends CreatePaymentIntentDto {
  @IsString()
  @IsOptional()
  email?: string;
}

export class CreateStripeCheckoutDto {
  @IsString()
  orderId!: string;

  @IsString()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  successUrl?: string;

  @IsString()
  @IsOptional()
  cancelUrl?: string;
}

export class CreateKonnectPaymentDto extends CreatePaymentIntentDto {
  @IsString()
  firstName!: string;

  @IsString()
  lastName!: string;

  @IsString()
  email!: string;

  @IsString()
  @IsOptional()
  phone?: string;
}

export class CreatePayPalPaymentDto extends CreatePaymentIntentDto {
  @IsString()
  @IsOptional()
  returnUrl?: string;

  @IsString()
  @IsOptional()
  cancelUrl?: string;
}

export class PayPalCreateOrderDto {
  @IsString()
  orderId!: string;

  @IsNumber()
  @IsOptional()
  amount?: number;

  @IsString()
  @IsOptional()
  returnUrl?: string;

  @IsString()
  @IsOptional()
  cancelUrl?: string;
}

export class PayPalCaptureOrderDto {
  @IsString()
  paypalOrderId!: string;

  @IsString()
  orderId!: string;
}
