import { IsEnum, IsOptional, IsString } from 'class-validator';
import { Prisma } from '@prisma/client';
import { PayoutMethod } from '@prisma/client';

export class LivreurProfileDto {
  @IsString() @IsOptional() fullName?: string;
  @IsString() @IsOptional() phone?: string;
  @IsString() @IsOptional() vehicleType?: string;
  @IsString() @IsOptional() zone?: string;
  @IsString() @IsOptional() cinOrPassportNumber?: string;
  @IsString() @IsOptional() bankAccountNumber?: string;
  @IsString() @IsOptional() licensePhotoUrl?: string;
  @IsString() @IsOptional() vehicleOwnershipDocUrl?: string;
  @IsString() @IsOptional() vehiclePhotoUrl?: string;
  @IsEnum(PayoutMethod) @IsOptional() payoutMethod?: PayoutMethod;
  @IsOptional() payoutDetails?: Prisma.InputJsonValue;
  @IsOptional() notificationPreferences?: {
    newOffers?: boolean;
    orderUpdates?: boolean;
  };
}
