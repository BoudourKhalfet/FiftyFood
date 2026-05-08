import { IsArray, IsOptional, IsString } from 'class-validator';

export class AiVerifyPhotoDto {
  @IsString()
  imageUrl!: string;

  @IsArray()
  @IsOptional()
  categories?: string[];
}
