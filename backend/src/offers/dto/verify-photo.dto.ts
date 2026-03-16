import { IsString } from 'class-validator';

export class VerifyPhotoDto {
  @IsString()
  image!: string; // base64 data URL
}
