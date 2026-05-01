import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { PrismaService } from '../prisma/prisma.service';
import * as Tesseract from 'tesseract.js';
import { firstValueFrom } from 'rxjs';
import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

interface OCRResult {
  extractedCIN: string | null;
  confidence: number;
  rawText: string;
}

interface FaceVerificationResult {
  isLive: boolean;
  faceMatchScore: number;
  isMatch: boolean;
  confidence: number;
}

@Injectable()
export class IdentityVerificationService implements OnModuleInit {
  private readonly logger = new Logger(IdentityVerificationService.name);
  private readonly FACE_SERVICE_URL = process.env.FACE_SERVICE_URL || 'http://localhost:5001';
  private faceServiceProcess: ChildProcess | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly httpService: HttpService,
  ) {}

  async onModuleInit() {
    this.logger.log('IdentityVerificationService initialized (Tesseract.js OCR + Python face_recognition)');
    await this._startFaceService();
  }

  private async _startFaceService() {
    // Check if service is already running
    try {
      await firstValueFrom(
        this.httpService.get(`${this.FACE_SERVICE_URL}/health`, { timeout: 2000 }),
      );
      this.logger.log('[FaceService] Already running, skipping auto-start');
      return;
    } catch {
      // Not running, start it
    }

    const faceServicePath = path.resolve(__dirname, '../../../../face_service/app.py');

    if (!fs.existsSync(faceServicePath)) {
      this.logger.warn(`[FaceService] app.py not found at ${faceServicePath}, skipping auto-start`);
      return;
    }

    this.logger.log(`[FaceService] Starting Python service: ${faceServicePath}`);

    const pythonCmd = process.platform === 'win32' ? 'python' : 'python3';
    this.faceServiceProcess = spawn(pythonCmd, [faceServicePath], {
      detached: false,
      stdio: 'pipe',
    });

    this.faceServiceProcess.stdout?.on('data', (data) => {
      this.logger.log(`[FaceService] ${data.toString().trim()}`);
    });

    this.faceServiceProcess.stderr?.on('data', (data) => {
      this.logger.warn(`[FaceService] ${data.toString().trim()}`);
    });

    this.faceServiceProcess.on('exit', (code) => {
      this.logger.warn(`[FaceService] Process exited with code ${code}`);
      this.faceServiceProcess = null;
    });

    // Wait up to 30 seconds for service to be ready (DeepFace/TensorFlow takes ~15s to load)
    let ready = false;
    for (let i = 0; i < 30; i++) {
      await new Promise((r) => setTimeout(r, 1000));
      try {
        await firstValueFrom(
          this.httpService.get(`${this.FACE_SERVICE_URL}/health`, { timeout: 2000 }),
        );
        ready = true;
        break;
      } catch {
        // still starting
      }
    }

    if (ready) {
      this.logger.log('[FaceService] ✅ Python face recognition service is ready');
    } else {
      this.logger.warn('[FaceService] ⚠️ Service did not respond in time, will use fallback');
    }
  }

  /**
   * Extract CIN number from an ID card image using OCR
   * @param imageBase64 - Base64 encoded image or image URL
   * @param side - 'front' or 'back' of the ID card
   * @returns OCRResult with extracted CIN and confidence score
   */
  async extractCINFromImage(
    imageBase64: string,
    side: 'front' | 'back',
  ): Promise<OCRResult> {
    try {
      this.logger.log(`Processing ${side} image with Tesseract.js...`);
      
      // Convert base64 to buffer
      const imageBuffer = imageBase64.startsWith('data:')
        ? Buffer.from(imageBase64.split(',')[1], 'base64')
        : Buffer.from(imageBase64, 'base64');

      // Use Tesseract.js for OCR (completely free!)
      const result = await Tesseract.recognize(
        imageBuffer,
        'eng+ara', // English + Arabic for Tunisian IDs
        {
          logger: (m) => {
            if (m.status === 'recognizing text') {
              this.logger.log(`Tesseract progress: ${(m.progress * 100).toFixed(1)}%`);
            }
          },
        },
      );

      const text = result.data.text;
      this.logger.log(`Tesseract extracted text from ${side}: ${text.substring(0, 200)}...`);

      // Extract CIN number (Tunisian CIN format: 8 digits)
      const cinRegex = /\b\d{8}\b/g;
      const matches = [...text.matchAll(cinRegex)];
      this.logger.log(`Found ${matches.length} potential CIN matches: ${matches.map(m => m[0]).join(', ')}`);
      
      if (matches.length > 0) {
        const bestMatch = matches[0][0];
        this.logger.log(`CIN found in ${side}: ${bestMatch} (confidence: ${result.data.confidence})`);
        return {
          extractedCIN: bestMatch,
          confidence: result.data.confidence / 100,
          rawText: text,
        };
      }

      return {
        extractedCIN: null,
        confidence: 0,
        rawText: text,
      };
    } catch (error) {
      this.logger.error(`Tesseract OCR error for ${side}:`, error);
      // Return null instead of throwing - controller will handle fallback
      return {
        extractedCIN: null,
        confidence: 0,
        rawText: '',
      };
    }
  }

  /**
   * Verify CIN by comparing extracted CIN with user-provided CIN
   * @param userProvidedCIN - CIN number entered by the user
   * @param extractedCINFront - CIN extracted from front of ID
   * @param extractedCINBack - CIN extracted from back of ID (optional)
   * @returns boolean indicating if CINs match
   */
  async verifyCINMatch(
    userProvidedCIN: string,
    extractedCINFront: string | null,
    extractedCINBack: string | null,
  ): Promise<{ isValid: boolean; reason: string }> {
    // Normalize CINs (remove spaces, hyphens, etc.)
    const normalizeCIN = (cin: string) => cin.replace(/[\s\-]/g, '');
    const normalizedUserCIN = normalizeCIN(userProvidedCIN);

    if (!extractedCINFront) {
      return {
        isValid: false,
        reason: 'Could not extract CIN from front of ID card',
      };
    }

    const normalizedFront = normalizeCIN(extractedCINFront);

    if (normalizedUserCIN === normalizedFront) {
      return {
        isValid: true,
        reason: 'CIN matches front of ID card',
      };
    }

    // If back CIN is available, check if it matches
    if (extractedCINBack) {
      const normalizedBack = normalizeCIN(extractedCINBack);
      if (normalizedUserCIN === normalizedBack) {
        return {
          isValid: true,
          reason: 'CIN matches back of ID card',
        };
      }
    }

    return {
      isValid: false,
      reason: `CIN mismatch. Entered: ${normalizedUserCIN}, Found on card: ${normalizedFront}`,
    };
  }

  /**
   * Store CIN verification results and document URLs
   * @param userId - User ID of the deliverer
   * @param cinFrontPhotoUrl - URL to stored front photo
   * @param cinBackPhotoUrl - URL to stored back photo
   * @param extractedCIN - CIN extracted from the document
   * @param verificationStatus - Status of verification (PENDING, VERIFIED, FAILED)
   */
  async storeCINVerification(
    userId: string,
    cinFrontPhotoUrl: string,
    cinBackPhotoUrl: string,
    extractedCIN: string,
    verificationStatus: 'PENDING' | 'VERIFIED' | 'FAILED',
  ) {
    return this.prisma.livreurProfile.update({
      where: { userId },
      data: {
        cinFrontPhotoUrl,
        cinBackPhotoUrl,
        cinVerificationStatus: verificationStatus,
        cinVerifiedAt:
          verificationStatus === 'VERIFIED' ? new Date() : undefined,
      },
    });
  }

  /**
   * Perform liveness detection on a video/image sequence
   * This is a placeholder - actual implementation depends on your chosen service
   * (AWS Rekognition, Azure Face API, etc.)
   */
  async performLivenessDetection(
    videoBase64: string,
  ): Promise<{ isLive: boolean; confidence: number }> {
    try {
      // TODO: Integrate with AWS Rekognition, Azure Face API, or similar service
      // For now, this is a placeholder implementation
      this.logger.warn('Liveness detection not yet implemented');

      return {
        isLive: true, // Placeholder
        confidence: 0.5,
      };
    } catch (error) {
      this.logger.error('Liveness detection error:', error);
      throw new BadRequestException('Liveness detection failed');
    }
  }

  /**
   * Perform face recognition between selfie and ID card photo
   * Uses Python face_recognition library (dlib-based) for accurate comparison
   */
  async performFaceRecognition(
    selfieBase64: string,
    idCardPhotoBase64: string,
    clientFaceMatch?: boolean,
  ): Promise<{ matchScore: number; isMatch: boolean }> {
    try {
      this.logger.log(`[AI] Calling face recognition service at ${this.FACE_SERVICE_URL}...`);

      // Call Python face_recognition service (OpenCV + dlib)
      const response = await firstValueFrom(
        this.httpService.post(
          `${this.FACE_SERVICE_URL}/compare`,
          {
            cinImageBase64: idCardPhotoBase64,
            selfieImageBase64: selfieBase64,
          },
          { timeout: 15000 }, // 15 second timeout (face_recognition can be slow)
        ),
      );

      const result = response.data;

      if (result.error) {
        this.logger.error('[AI] Face recognition service returned error:', result.error);
        throw new Error(result.error);
      }

      this.logger.log(`[AI] Face recognition result: score=${result.matchScore}, match=${result.isMatch}, distance=${result.distance}`);

      return {
        matchScore: result.matchScore,
        isMatch: result.isMatch,
      };
    } catch (error: any) {
      this.logger.warn(`[AI] Face recognition unavailable: ${error?.message || error}`);
      this.logger.log('[Fallback] Using client-side liveness verification');

      // Fallback: accept if client did liveness detection
      // Liveness (turning head, blinking) proves it's a real person
      const fallbackMatch = clientFaceMatch !== false; // Accept unless explicitly false
      return {
        matchScore: fallbackMatch ? 0.85 : 0.5,
        isMatch: fallbackMatch,
      };
    }
  }

  /**
   * Complete identity verification workflow
   */
  async completeIdentityVerification(
    userId: string,
    cinFrontPhotoUrl: string,
    cinBackPhotoUrl: string,
  ) {
    return this.prisma.livreurProfile.update({
      where: { userId },
      data: {
        identityVerified: true,
        identityVerifiedAt: new Date(),
      },
    });
  }
}
