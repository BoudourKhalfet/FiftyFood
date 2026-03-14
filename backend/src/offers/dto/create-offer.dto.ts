import {
  IsString,
  IsNumber,
  IsEnum,
  IsBoolean,
  IsOptional,
  Min,
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

  @IsEnum(['IDENTIFIED', 'ANONYMOUS'])
  @IsOptional()
  visibility?: 'IDENTIFIED' | 'ANONYMOUS';

  @IsBoolean()
  @IsOptional()
  deliveryAvailable?: boolean;
}
