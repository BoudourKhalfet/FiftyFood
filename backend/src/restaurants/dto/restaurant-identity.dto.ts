import { EstablishmentType } from '@prisma/client';
import { IsEnum, IsString } from 'class-validator';

export class RestaurantIdentityDto {
  @IsString()
  restaurantName!: string;

  @IsEnum(EstablishmentType)
  establishmentType!: EstablishmentType;

  @IsString()
  phone!: string;

  @IsString()
  address!: string;

  @IsString()
  city!: string;
}
