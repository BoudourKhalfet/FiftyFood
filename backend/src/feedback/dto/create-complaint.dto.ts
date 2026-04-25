import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateComplaintDto {
  @IsString()
  orderId!: string;

  @IsString()
  @IsIn(['RESTAURANT', 'DELIVERER'])
  targetType!: 'RESTAURANT' | 'DELIVERER';

  @IsString()
  @MaxLength(180)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(800)
  description?: string;
}
