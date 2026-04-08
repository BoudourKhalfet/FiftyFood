import { OfferVisibility } from '@prisma/client';
import {
  IsString,
  IsNumber,
  IsEnum,
  IsBoolean,
  IsOptional,
  Min,
  IsISO8601,
} from 'class-validator';

export class CreateOfferDto {
  @IsString()
  photoUrl!: string;

  @IsString()
  description!: string;

  @IsNumber()
  @Min(0.01)
  originalPrice!: number;

  @IsNumber()
  @Min(0.01)
  discountedPrice!: number;

  @IsNumber()
  @Min(1)
  quantity!: number;

  @IsString()
  pickupTime!: string;

  @IsISO8601()
  pickupDateTime?: string;

  @IsEnum(OfferVisibility)
  @IsOptional()
  visibility?: OfferVisibility;

  @IsBoolean()
  @IsOptional()
  deliveryAvailable?: boolean;
}
