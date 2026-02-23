import { IsEnum, IsString } from 'class-validator';
import { OwnershipType } from '@prisma/client';

export class RestaurantLegalDto {
  @IsString()
  legalEntityName!: string;

  @IsString()
  registrationNumberRNE!: string;

  @IsEnum(OwnershipType)
  ownershipType!: OwnershipType;
}
