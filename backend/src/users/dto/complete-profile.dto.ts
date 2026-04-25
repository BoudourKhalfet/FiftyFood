import { ArrayMinSize, IsArray, IsEnum, IsString } from 'class-validator';
import { CuisinePreference } from '@prisma/client';

export class CompleteProfileDto {
  @IsString()
  fullName!: string;

  @IsString()
  phone!: string;

  @IsString()
  defaultAddress!: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(CuisinePreference, { each: true })
  cuisinePreferences!: CuisinePreference[];
}
