import { IsArray, IsOptional, IsString } from 'class-validator';

export class UpdatePreferencesDto {
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  cuisinePreferences?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  dietaryRestrictions?: string[];
}
