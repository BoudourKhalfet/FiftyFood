import { IsString, IsNotEmpty, IsEnum, IsBoolean, IsOptional } from 'class-validator';

export class VerifyCINDto {
  @IsString()
  @IsNotEmpty()
  cinNumber!: string;

  @IsString()
  @IsNotEmpty()
  // Accepts data URI format: data:image/jpeg;base64,xxx
  cinFrontImageBase64!: string;

  @IsString()
  @IsNotEmpty()
  // Accepts data URI format: data:image/jpeg;base64,xxx
  cinBackImageBase64!: string;

  @IsBoolean()
  @IsOptional()
  ocrVerified?: boolean; // Optional: indicates if client-side OCR verification passed
}

export class VerifyFaceDto {
  @IsString()
  @IsNotEmpty()
  // Accepts data URI format: data:image/jpeg;base64,xxx
  selfieImageBase64!: string;

  @IsString()
  @IsOptional()
  livenessVideoBase64?: string; // Optional: video sequence for liveness detection

  @IsBoolean()
  @IsOptional()
  faceMatch?: boolean; // Optional: client-side face comparison result

  @IsString()
  @IsOptional()
  cinNumber?: string; // Optional: CIN number for reference
}

export class IdentityVerificationResponseDto {
  @IsBoolean()
  success!: boolean;

  @IsString()
  message!: string;

  @IsEnum(['CIN_VERIFICATION', 'FACE_VERIFICATION', 'COMPLETED'])
  step!: 'CIN_VERIFICATION' | 'FACE_VERIFICATION' | 'COMPLETED';

  @IsOptional()
  details?: {
    extractedCIN?: string;
    matchScore?: number;
    confidence?: number;
  };
}
