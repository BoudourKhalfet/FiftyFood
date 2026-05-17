import {
  IsString,
  IsNotEmpty,
  IsEnum,
  IsBoolean,
  IsOptional,
  IsArray,
  IsNumber,
} from 'class-validator';

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
  livenessSessionId!: string; // Must be a consumed (passed) liveness session

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

  @IsString()
  @IsOptional()
  cinFrontImageBase64?: string; // Optional: CIN front image for server-side face comparison
}

export class LivenessVerifyDto {
  @IsString()
  @IsNotEmpty()
  sessionId!: string; // server-issued session ID

  @IsString()
  @IsNotEmpty()
  nonce!: string; // server-issued nonce for this session

  @IsArray()
  @IsNotEmpty()
  frames!: string[]; // base64-encoded frames captured during challenges

  @IsArray()
  @IsNotEmpty()
  challenges!: string[]; // 2-step sequence, e.g. ["blink", "turn_left"]

  @IsArray()
  @IsNotEmpty()
  telemetry!: Array<{
    timestamp: number;
    headEulerAngleX: number;
    headEulerAngleY: number;
    smilingProbability: number;
    leftEyeOpenProbability: number;
    rightEyeOpenProbability: number;
    faceWidth: number;
    faceHeight: number;
    faceCenterX: number;
    faceCenterY: number;
  }>; // per-frame ML Kit measurements — server validates challenge from this

  @IsString()
  @IsNotEmpty()
  selfieImageBase64!: string; // best frame for face comparison

  @IsString()
  @IsOptional()
  cinFrontImageBase64?: string; // optional CIN image for comparison
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
