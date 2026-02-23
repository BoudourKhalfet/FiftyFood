import { PayoutMethod, Prisma } from '@prisma/client';
import { IsEnum, IsObject, IsOptional } from 'class-validator';

export class RestaurantPayoutDto {
  @IsOptional()
  @IsEnum(PayoutMethod)
  payoutMethod?: PayoutMethod;

  // free JSON object
  @IsOptional()
  @IsObject()
  payoutDetails?: Prisma.InputJsonValue;
}
