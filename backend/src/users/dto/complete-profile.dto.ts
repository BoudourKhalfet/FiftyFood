import { ArrayMinSize, IsArray, IsEnum, IsOptional, IsString } from 'class-validator';
import { ClientType, CuisinePreference } from '@prisma/client';

export class CompleteProfileDto {
  @IsOptional()
  @IsEnum(ClientType)
  clientType?: ClientType;

  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  defaultAddress?: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(CuisinePreference, { each: true })
  cuisinePreferences!: CuisinePreference[];

  @IsOptional()
  @IsString()
  societyName?: string;

  @IsOptional()
  @IsString()
  fiscalNumber?: string;

  @IsOptional()
  @IsString()
  proPhone?: string;

  @IsOptional()
  @IsString()
  proAddress?: string;
}
