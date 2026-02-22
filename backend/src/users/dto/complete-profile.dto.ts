import { ArrayMinSize, IsArray, IsEnum, IsString } from 'class-validator';
import { CuisinePreference, DietaryRestriction } from '@prisma/client';

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

  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(DietaryRestriction, { each: true })
  dietaryRestrictions!: DietaryRestriction[];
}
