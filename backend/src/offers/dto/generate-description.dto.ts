import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class GenerateDescriptionDto {
  @IsString()
  @IsNotEmpty()
  imageUrl!: string; // URL of the uploaded image

  @IsString()
  @IsOptional()
  language?: string; // Language code: 'en', 'fr', 'ar'
}
