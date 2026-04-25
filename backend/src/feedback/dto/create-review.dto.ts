import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateReviewDto {
  @IsString()
  orderId!: string;

  @IsString()
  @IsIn(['RESTAURANT', 'DELIVERER'])
  targetType!: 'RESTAURANT' | 'DELIVERER';

  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}
