import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class UpdateOfferDto {
  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @Min(0.01)
  @IsOptional()
  originalPrice?: number;

  @IsNumber()
  @Min(0.01)
  @IsOptional()
  discountedPrice?: number;

  @IsNumber()
  @Min(1)
  @IsOptional()
  quantity?: number;

  @IsString()
  @IsOptional()
  pickupTime?: string;
}
