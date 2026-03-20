import { IsString, IsNumber, IsOptional, IsObject } from 'class-validator';

export enum CollectionMethod {
  PICKUP = 'PICKUP',
  DELIVERY = 'DELIVERY',
}

export enum PaymentMethod {
  CARD = 'CARD',
  D17 = 'D17',
  CASH = 'CASH',
}

export class CreateOrderDto {
  @IsString()
  restaurantId!: string;

  @IsObject()
  items!: any;

  @IsNumber()
  total!: number;

  @IsString()
  @IsOptional()
  collectionMethod?: CollectionMethod;

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
  paymentMethod?: PaymentMethod;

  @IsObject()
  @IsOptional()
  paymentDetails?: any;
}
