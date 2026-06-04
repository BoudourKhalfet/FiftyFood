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

  private readonly FACE_SERVICE_URL =
    process.env.FACE_SERVICE_URL || 'http://localhost:5001';

  private faceServiceProcess: ChildProcess | null = null;

  constructor(
    private readonly prisma: PrismaService,

    private readonly httpService: HttpService,
  ) {}

  async onModuleInit() {
    this.logger.log(
      'IdentityVerificationService initialized (Tesseract.js OCR + Python face_recognition)',
    );

    await this._startFaceService();
  }

  private async _startFaceService() {
    // Check if service is already running

    try {
      await firstValueFrom(
        this.httpService.get(`${this.FACE_SERVICE_URL}/health`, {
          timeout: 2000,
        }),
      );

      this.logger.log('[FaceService] Already running, skipping auto-start');

      return;
    } catch {
      // Not running, start it
    }

    const faceServicePath = path.resolve(
      __dirname,
      '../../../../face_service/app.py',
    );

    if (!fs.existsSync(faceServicePath)) {
      this.logger.warn(
        `[FaceService] app.py not found at ${faceServicePath}, skipping auto-start`,
      );

      return;
    }

    this.logger.log(
      `[FaceService] Starting Python service: ${faceServicePath}`,
    );

    const pythonCmd = process.platform === 'win32' ? 'python' : 'python3';

    this.faceServiceProcess = spawn(pythonCmd, [faceServicePath], {
      detached: false,

      stdio: 'pipe',
    });

    this.faceServiceProcess.stdout?.on('data', (data) => {
      this.logger.log(`[FaceService] ${data.toString().trim()}`);
    });

    this.faceServiceProcess.stderr?.on('data', (data) => {
      this.logger.debug(`[FaceService] ${data.toString().trim()}`);
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
          this.httpService.get(`${this.FACE_SERVICE_URL}/health`, {
            timeout: 2000,
          }),
        );

        ready = true;

        break;
      } catch {
        // still starting
      }
    }

    if (ready) {
      this.logger.log(
        '[FaceService] ✅ Python face recognition service is ready',
      );
    } else {
      this.logger.warn(
        '[FaceService] ⚠️ Service did not respond in time, will use fallback',
      );
    }
  }

  /**

   * Extract CIN number from an ID card image using OCR

   * @param imageBase64 - Base64 encoded image or image URL

   * @param side - 'front' or 'back' of the ID card

   * @returns OCRResult with extracted CIN and confidence score

   */

  /**
   * Fix common OCR misreads for digits
   */
  private correctOCRDigits(text: string): string {
    return text
      .replace(/[Oo]/g, '0')
      .replace(/[IlL|]/g, '1')
      .replace(/[Zz]/g, '2')
      .replace(/[Ss]/g, '5')
      .replace(/[Bb]/g, '8')
      .replace(/[Gg]/g, '9');
  }

  /**
   * Diagnose why OCR extraction failed (cropped, blurry, etc.)
   * Returns specific failure reason for better UX
   */
  async diagnoseCINExtractionFailure(imageBase64: string): Promise<string> {
    try {
      const imageBuffer = imageBase64.startsWith('data:')
        ? Buffer.from(imageBase64.split(',')[1], 'base64')
        : Buffer.from(imageBase64, 'base64');

      // Try OCR to check if text exists
      const worker = await Tesseract.createWorker('eng');
      await worker.setParameters({
        tessedit_pageseg_mode: Tesseract.PSM.SINGLE_BLOCK,
        tessedit_char_whitelist:
          '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ',
      } as any);

      const result = await worker.recognize(imageBuffer);
      const ocrText = result.data.text;
      await worker.terminate();

      // If OCR extracted text but no 8-digit number found
      if (ocrText && ocrText.trim().length > 0) {
        return 'CIN number is not visible or cropped. The image contains text but the CIN number cannot be read. Please ensure the entire ID card (including all edges) is clearly visible in the photo.';
      }

      // If no text at all, likely image quality issue
      return 'Could not read any text from the photo. Please retake with better lighting and ensure the entire ID card is clearly visible.';
    } catch (error) {
      this.logger.debug(`Diagnosis failed (non-critical): ${error}`);
      return 'Could not read CIN from the photo. Please retake with better lighting and ensure the entire ID card is clearly visible.';
    }
  }

  /**
   * Try to extract 8-digit CIN from OCR text
   */
  private extractCINFromText(text: string): string | null {
    // First try exact 8-digit match on raw text
    const exactRegex = /\b\d{8}\b/g;
    const exactMatches = [...text.matchAll(exactRegex)];
    if (exactMatches.length > 0) return exactMatches[0][0];

    // Try after correcting common OCR digit misreads
    const corrected = this.correctOCRDigits(text);
    const correctedMatches = [...corrected.matchAll(exactRegex)];
    if (correctedMatches.length > 0) return correctedMatches[0][0];

    // Try finding any run of 8+ digits and take the first 8
    const looseRegex = /\d{8,}/g;
    const looseMatches = [...corrected.matchAll(looseRegex)];
    if (looseMatches.length > 0) return looseMatches[0][0].substring(0, 8);

    return null;
  }

  async extractCINFromImage(
    imageBase64: string,

    side: 'front' | 'back',
  ): Promise<OCRResult> {
    try {
      const normalizeBase64 = (b64: string) =>
        b64.startsWith('data:') ? b64.split(',')[1] : b64;

      // Deskew the image before OCR to fix tilted card photos
      const originalBase64 = normalizeBase64(imageBase64);
      let processedBase64 = originalBase64;
      try {
        const deskewRes = await firstValueFrom(
          this.httpService.post(
            `${this.FACE_SERVICE_URL}/deskew`,
            { image: processedBase64 },
            { timeout: 8000 },
          ),
        );
        if (deskewRes.data?.image) {
          processedBase64 = deskewRes.data.image;
        }
      } catch {
        // Deskew unavailable — proceed with original image
      }

      const rotateImage = async (rawB64: string, angle: number) => {
        try {
          const rotateRes = await firstValueFrom(
            this.httpService.post(
              `${this.FACE_SERVICE_URL}/rotate`,
              { image: rawB64, angle },
              { timeout: 8000 },
            ),
          );
          if (rotateRes.data?.image) {
            return rotateRes.data.image as string;
          }
        } catch {
          // Rotation unavailable — skip
        }
        return null;
      };

      const base64Seeds: string[] = [originalBase64];
      if (processedBase64 && processedBase64 !== originalBase64) {
        base64Seeds.push(processedBase64);
      }

      const base64Variants: { b64: string; angle: number }[] = [];
      for (const seed of base64Seeds) {
        base64Variants.push({ b64: seed, angle: 0 });
        for (const angle of [90, 180, 270]) {
          const rotated = await rotateImage(seed, angle);
          if (rotated) base64Variants.push({ b64: rotated, angle });
        }
      }

      // Pass 1: Use eng only with PSM 6 (uniform block of text)
      // Arabic mode confuses digit recognition on Tunisian IDs
      const worker = await Tesseract.createWorker('eng');
      await worker.setParameters({
        tessedit_pageseg_mode: Tesseract.PSM.SINGLE_BLOCK,
        tessedit_char_whitelist:
          '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ',
      } as any);
      let fallbackText = '';
      let fallbackConfidence = 0;

      for (const variant of base64Variants) {
        const imageBuffer = Buffer.from(variant.b64, 'base64');

        const result = await worker.recognize(imageBuffer);
        const text = result.data.text;
        if (!fallbackText) {
          fallbackText = text;
          fallbackConfidence = result.data.confidence / 100;
        }
        let cin = this.extractCINFromText(text);
        if (cin) {
          if (variant.angle !== 0) {
            this.logger.log(
              `[CIN OCR] side=${side} success at rotation=${variant.angle}deg`,
            );
          }
          await worker.terminate();
          return {
            extractedCIN: cin,
            confidence: result.data.confidence / 100,
            rawText: text,
          };
        }

        // Pass 2: Try PSM 11 (sparse text) if first pass found nothing
        await worker.setParameters({
          tessedit_pageseg_mode: Tesseract.PSM.SPARSE_TEXT,
        } as any);
        const result2 = await worker.recognize(imageBuffer);
        cin = this.extractCINFromText(result2.data.text);
        if (cin) {
          if (variant.angle !== 0) {
            this.logger.log(
              `[CIN OCR] side=${side} success at rotation=${variant.angle}deg (PSM11)`,
            );
          }
          await worker.terminate();
          return {
            extractedCIN: cin,
            confidence: result2.data.confidence / 100,
            rawText: result2.data.text,
          };
        }

        // Pass 3: Try PSM 7 (single line) — CIN is often on its own line
        await worker.setParameters({
          tessedit_pageseg_mode: Tesseract.PSM.SINGLE_LINE,
          tessedit_char_whitelist: '0123456789',
        } as any);
        const result3 = await worker.recognize(imageBuffer);
        cin = this.extractCINFromText(result3.data.text);
        if (cin) {
          if (variant.angle !== 0) {
            this.logger.log(
              `[CIN OCR] side=${side} success at rotation=${variant.angle}deg (PSM7)`,
            );
          }
          await worker.terminate();
          return {
            extractedCIN: cin,
            confidence: result3.data.confidence / 100,
            rawText: result3.data.text,
          };
        }

        await worker.setParameters({
          tessedit_pageseg_mode: Tesseract.PSM.SINGLE_BLOCK,
          tessedit_char_whitelist:
            '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ',
        } as any);
      }

      await worker.terminate();

      this.logger.warn(
        `[CIN OCR] side=${side} failed after rotations (0/90/180/270)`,
      );
      return {
        extractedCIN: null,

        confidence: fallbackConfidence,

        rawText: fallbackText,
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

  async storeCINVerificationStatus(
    userId: string,
    verificationStatus: 'PENDING' | 'VERIFIED' | 'FAILED',
  ) {
    return this.prisma.livreurProfile.update({
      where: { userId },
      data: { cinVerificationStatus: verificationStatus },
    });
  }

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
   * Perform layered liveness verification using challenge-response frames + telemetry.
   * Server-side validation: challenges, timing, replay detection, confidence scoring.
   */
  async performLivenessVerification(
    frames: string[],
    challenges: string[],
    telemetry: any[],
  ): Promise<{
    isLive: boolean;
    confidence: number;
    reason: string;
    riskLevel: string;
    checks: any;
  }> {
    try {
      const response = await firstValueFrom(
        this.httpService.post(
          `${this.FACE_SERVICE_URL}/liveness`,
          { frames, challenges, telemetry },
          { timeout: 45000 },
        ),
      );

      const result = response.data;
      return {
        isLive: result.isLive === true,
        confidence: result.confidence ?? 0,
        reason: result.reason ?? '',
        riskLevel: result.riskLevel ?? 'HIGH',
        checks: result.checks ?? {},
      };
    } catch (error: any) {
      this.logger.error(
        '[Liveness] Service unavailable:',
        error?.message || error,
      );
      throw new BadRequestException(
        'Liveness verification service is temporarily unavailable. Please try again later.',
      );
    }
  }

  /**
   * Simple face-presence check (backward compat, used by verifyFace endpoint).
   */
  async performLivenessDetection(
    imageBase64: string,
  ): Promise<{ isLive: boolean; confidence: number }> {
    try {
      const response = await firstValueFrom(
        this.httpService.post(
          `${this.FACE_SERVICE_URL}/detect`,
          { image: imageBase64 },
          { timeout: 10000 },
        ),
      );
      const hasFace = response.data?.has_face === true;
      return { isLive: hasFace, confidence: hasFace ? 0.8 : 0.0 };
    } catch (error) {
      this.logger.error('[Liveness] Face service unavailable:', error);
      throw new BadRequestException(
        'Face verification service is temporarily unavailable. Please try again later.',
      );
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
      // Call Python face_recognition service (OpenCV + dlib)

      const response = await firstValueFrom(
        this.httpService.post(
          `${this.FACE_SERVICE_URL}/compare`,

          {
            cinImageBase64: idCardPhotoBase64,
            selfieImageBase64: selfieBase64,
          },

          { timeout: 120000 }, // 120 second timeout (first call downloads models)
        ),
      );

      const result = response.data;

      if (result.error) {
        this.logger.error(
          '[AI] Face recognition service returned error:',
          result.error,
        );

        throw new Error(result.error);
      }

      return {
        matchScore: result.matchScore ?? 0,

        isMatch: result.isMatch === true,
      };
    } catch (error: any) {
      this.logger.error(
        `[AI] Face recognition service unavailable: ${error?.message || error}`,
      );

      throw new BadRequestException(
        'Face verification service is temporarily unavailable. Please try again later.',
      );
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

  /**

   * Extract and verify Tunisian ID barcode from back image

   * Uses Python script with pyzbar for PDF417 barcode detection

   */

  async extractTunisianBarcode(imageBase64: string): Promise<{
    cin: string | null;

    isValidFormat: boolean;

    rawData: string | null;
  }> {
    try {
      const normalizeBase64 = (b64: string) =>
        b64.startsWith('data:') ? b64.split(',')[1] : b64;

      const rotateImage = async (rawB64: string, angle: number) => {
        try {
          const rotateRes = await firstValueFrom(
            this.httpService.post(
              `${this.FACE_SERVICE_URL}/rotate`,
              { image: rawB64, angle },
              { timeout: 8000 },
            ),
          );
          if (rotateRes.data?.image) {
            return rotateRes.data.image as string;
          }
        } catch {
          // Rotation unavailable — skip
        }
        return null;
      };

      const base64Image = normalizeBase64(imageBase64);
      const variants: { b64: string; angle: number }[] = [
        { b64: base64Image, angle: 0 },
      ];
      for (const angle of [90, 180, 270]) {
        const rotated = await rotateImage(base64Image, angle);
        if (rotated) variants.push({ b64: rotated, angle });
      }

      let lastResult: any = null;

      for (const variant of variants) {
        // Call Python face service for barcode extraction
        const response = await firstValueFrom(
          this.httpService.post(
            `${this.FACE_SERVICE_URL}/extract-barcode`,
            {
              image: variant.b64,
            },
            { timeout: 10000 },
          ),
        );

        const result = response.data;
        lastResult = result;

        if (result.barcode && result.isTunisianFormat) {
          if (variant.angle !== 0) {
            this.logger.log(
              `[TunisianID] Barcode success at rotation=${variant.angle}deg`,
            );
          }
          return {
            cin: result.cin,

            isValidFormat: true,

            rawData: result.rawData,
          };
        }
      }

      this.logger.warn(
        `[TunisianID] Barcode not detected after rotations (0/90/180/270) details=${JSON.stringify(
          {
            barcode: lastResult?.barcode,
            isTunisianFormat: lastResult?.isTunisianFormat,
            error: lastResult?.error,
          },
        )}`,
      );

      return {
        cin: null,

        isValidFormat: false,

        rawData: null,
      };
    } catch (error) {
      this.logger.error('[TunisianID] Barcode extraction failed:', error);

      return {
        cin: null,

        isValidFormat: false,

        rawData: null,
      };
    }
  }

  /**

   * Detect Tunisian flag and visual features on front image

   * Uses color analysis to detect red flag with white crescent

   */

  async detectTunisianFeatures(imageBase64: string): Promise<{
    hasTunisianFlag: boolean;

    flagConfidence: number;

    hasSecurityFeatures: boolean;
  }> {
    try {
      const imageBuffer = imageBase64.startsWith('data:')
        ? Buffer.from(imageBase64.split(',')[1], 'base64')
        : Buffer.from(imageBase64, 'base64');

      // Call Python service for visual feature detection

      const response = await firstValueFrom(
        this.httpService.post(
          `${this.FACE_SERVICE_URL}/detect-tunisian-features`,
          {
            image: imageBuffer.toString('base64'),
          },
          { timeout: 10000 },
        ),
      );

      const result = response.data;

      return {
        hasTunisianFlag: result.hasTunisianFlag || false,

        flagConfidence: result.flagConfidence || 0,

        hasSecurityFeatures: result.hasSecurityFeatures || false,
      };
    } catch (error) {
      this.logger.error('[TunisianID] Feature detection failed:', error);

      return {
        hasTunisianFlag: false,

        flagConfidence: 0,

        hasSecurityFeatures: false,
      };
    }
  }

  /**

   * Comprehensive Tunisian ID verification

   * Combines OCR, barcode, and visual feature verification

   */

  async verifyTunisianDocument(
    cinFrontImageBase64: string,

    cinBackImageBase64: string,

    userProvidedCIN: string,
  ): Promise<{
    isValid: boolean;

    reason: string;

    checks: {
      ocrCin: string | null;

      barcodeCin: string | null;

      hasTunisianFlag: boolean;

      hasValidBarcode: boolean;

      cinConsistency: boolean;

      userCinMatch: boolean;
    };

    score: number;
  }> {
    const checks = {
      ocrCin: null as string | null,

      barcodeCin: null as string | null,

      hasTunisianFlag: false,

      hasValidBarcode: false,

      cinConsistency: false,

      userCinMatch: false,
    };

    // 1. Extract CIN from front using OCR (Tesseract)

    const frontOCR = await this.extractCINFromImage(
      cinFrontImageBase64,
      'front',
    );

    checks.ocrCin = frontOCR.extractedCIN;

    // 2. Extract CIN from barcode on back

    const barcodeResult = await this.extractTunisianBarcode(cinBackImageBase64);

    checks.barcodeCin = barcodeResult.cin;

    checks.hasValidBarcode = barcodeResult.isValidFormat;

    // 3. Detect Tunisian flag on front

    const features = await this.detectTunisianFeatures(cinFrontImageBase64);

    checks.hasTunisianFlag = features.hasTunisianFlag;

    // 4. Cross-verify: Front OCR CIN must match Barcode CIN

    if (checks.ocrCin && checks.barcodeCin) {
      checks.cinConsistency = checks.ocrCin === checks.barcodeCin;
    }

    // 5. Verify user-provided CIN matches extracted CIN

    const normalizedUser = userProvidedCIN.replace(/[\s\-]/g, '');

    if (checks.ocrCin) {
      checks.userCinMatch =
        normalizedUser === checks.ocrCin.replace(/[\s\-]/g, '');
    }

    // Determine validity
    // Primary gate: user-provided CIN must match OCR-extracted CIN from front
    // Barcode and flag are advisory signals — they boost confidence but are
    // not hard requirements (pyzbar may be absent; phone photos vary greatly)
    const barcodeAvailable =
      checks.hasValidBarcode && checks.barcodeCin !== null;

    let score = 0;
    if (barcodeAvailable) score += 0.3;
    if (checks.hasTunisianFlag) score += 0.2;
    if (checks.cinConsistency) score += 0.3; // only counted when barcode available
    if (checks.userCinMatch) score += 0.2;

    // When barcode is unavailable, reweight so OCR match alone can pass
    let isValid: boolean;
    let reason = 'Tunisian ID verification successful';

    if (!checks.hasTunisianFlag) {
      isValid = false;
      reason =
        'Tunisian flag not detected on the front of the ID card. Please retake the photo ensuring the full card is visible.';
    } else if (!barcodeAvailable) {
      isValid = false;
      reason =
        'No valid barcode detected on the back of the ID card. Please retake the back photo ensuring the barcode is clearly visible.';
    } else if (!checks.userCinMatch) {
      isValid = false;
      reason = checks.ocrCin
        ? 'Provided CIN does not match ID card'
        : 'Could not read CIN from the front of the ID card — please retake the photo';
    } else if (!checks.cinConsistency) {
      isValid = false;
      reason = 'CIN on front does not match barcode on back';
    } else {
      isValid = true;
    }

    if (!isValid) {
      this.logger.warn(
        `[TunisianID] failed reason="${reason}" ocr=${checks.ocrCin} barcode=${checks.barcodeCin} flag=${checks.hasTunisianFlag} barcodeValid=${checks.hasValidBarcode} cinMatch=${checks.userCinMatch} cinConsistency=${checks.cinConsistency}`,
      );
    }

    this.logger.log(
      `[TunisianID] ocr=${checks.ocrCin} barcode=${checks.barcodeCin} flag=${checks.hasTunisianFlag} valid=${isValid}`,
    );

    return {
      isValid,

      reason,

      checks,

      score,
    };
  }
}
