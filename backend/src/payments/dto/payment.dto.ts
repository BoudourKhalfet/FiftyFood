import { IsString, IsNumber, IsOptional, IsObject, IsEmail } from 'class-validator';

export enum PaymentMethod {
  CARD = 'CARD',
  EDINAR = 'EDINAR',
  PAYPAL = 'PAYPAL',
  D17 = 'D17',
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

export class CreateStripeIntentDto {
  @IsString()
  restaurantId!: string;

  @IsString()
  offerId!: string;

  @IsObject()
  items!: any;

  @IsNumber()
  total!: number;

  @IsString()
  @IsOptional()
  collectionMethod?: string;

  @IsString()
  @IsOptional()
  deliveryAddress?: string;

  @IsString()
  @IsOptional()
  deliveryPhone?: string;

  @IsNumber()
  @IsOptional()
  deliveryFee?: number;

  @IsString()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  orderId?: string;
}

export class CreateStripeCheckoutDto {
  @IsString()
  @IsOptional()
  orderId?: string;

  @IsString()
  restaurantId!: string;

  @IsString()
  offerId!: string;

  @IsObject()
  items!: any;

  @IsNumber()
  total!: number;

  @IsString()
  @IsOptional()
  collectionMethod?: string;

  @IsString()
  @IsOptional()
  deliveryAddress?: string;

  @IsString()
  @IsOptional()
  deliveryPhone?: string;

  @IsNumber()
  @IsOptional()
  deliveryFee?: number;

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

export class CreateKonnectPaymentDto {
  @IsString()
  orderId!: string;

  @IsString()
  firstName!: string;

  @IsString()
  lastName!: string;

  @IsEmail()
  email!: string;

  @IsString()
  @IsOptional()
  phone?: string;
}

export class CreatePayPalPaymentDto {
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
