import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  BadRequestException,
  Logger,
  Get,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { createHash } from 'crypto';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

import { IdentityVerificationService } from './identity-verification.service';

import {
  VerifyCINDto,
  VerifyFaceDto,
  LivenessVerifyDto,
  IdentityVerificationResponseDto,
} from './dto/identity-verification.dto';

import { LivreurService } from './livreur.service';

import { LivenessSessionService } from './liveness-session.service';

interface ReqWithUser {
  user: { sub: string };
}

@Controller('livreur/verify')
@UseGuards(JwtAuthGuard)
export class IdentityVerificationController {
  private readonly logger = new Logger(IdentityVerificationController.name);

  constructor(
    private readonly identityVerificationService: IdentityVerificationService,

    private readonly livreurService: LivreurService,

    private readonly livenessSessionService: LivenessSessionService,
  ) {}

  /**

   * Step 1: Verify CIN by extracting from images and comparing with user input

   * POST /livreur/verify/cin

   */

  @Post('cin')
  async verifyCIN(
    @Req() req: ReqWithUser,

    @Body() dto: VerifyCINDto,
  ): Promise<IdentityVerificationResponseDto> {
    const userId = req.user.sub;

    this.logger.log(`[CIN] Start user=${userId} cin=${dto.cinNumber}`);

    try {
      let frontExtractedCIN: string | null = null;
      const frontOCR =
        await this.identityVerificationService.extractCINFromImage(
          dto.cinFrontImageBase64,
          'front',
        );
      frontExtractedCIN = frontOCR.extractedCIN;

      if (dto.cinBackImageBase64) {
        const tunisianVerification =
          await this.identityVerificationService.verifyTunisianDocument(
            dto.cinFrontImageBase64,
            dto.cinBackImageBase64,
            dto.cinNumber,
          );

        this.logger.log(
          `[CIN] Doc check: valid=${tunisianVerification.isValid} score=${tunisianVerification.score.toFixed(2)} barcode=${tunisianVerification.checks.hasValidBarcode} flag=${tunisianVerification.checks.hasTunisianFlag} cinMatch=${tunisianVerification.checks.userCinMatch}`,
        );

        if (!tunisianVerification.isValid) {
          await this.identityVerificationService.storeCINVerificationStatus(
            userId,
            'FAILED',
          );
          throw new BadRequestException({
            message: tunisianVerification.reason,
            step: 'TUNISIAN_DOCUMENT_VERIFICATION',
            details: tunisianVerification.checks,
          });
        }

        // Use the verified CIN from comprehensive check
        frontExtractedCIN =
          tunisianVerification.checks.ocrCin || frontExtractedCIN;
      }

      const cinVerification =
        await this.identityVerificationService.verifyCINMatch(
          dto.cinNumber,

          frontExtractedCIN,

          null, // CIN is only on the front of Tunisian IDs
        );

      if (!cinVerification.isValid) {
        await this.identityVerificationService.storeCINVerificationStatus(
          userId,
          'FAILED',
        );

        // If extraction failed (no CIN found), provide diagnostic reason
        let errorMessage = cinVerification.reason;
        if (!frontExtractedCIN) {
          const diagnosticReason =
            await this.identityVerificationService.diagnoseCINExtractionFailure(
              dto.cinFrontImageBase64,
            );
          errorMessage = diagnosticReason;
        }

        throw new BadRequestException({
          message: errorMessage,

          step: 'CIN_VERIFICATION',
        });
      }

      // Save CIN images to local disk under uploads/cin-images/{userId}/
      const cinDir = path.join(process.cwd(), 'uploads', 'cin-images', userId);
      if (!fs.existsSync(cinDir)) fs.mkdirSync(cinDir, { recursive: true });

      const frontBuffer = dto.cinFrontImageBase64.startsWith('data:')
        ? Buffer.from(dto.cinFrontImageBase64.split(',')[1], 'base64')
        : Buffer.from(dto.cinFrontImageBase64, 'base64');
      const backBuffer = dto.cinBackImageBase64.startsWith('data:')
        ? Buffer.from(dto.cinBackImageBase64.split(',')[1], 'base64')
        : Buffer.from(dto.cinBackImageBase64, 'base64');

      fs.writeFileSync(path.join(cinDir, 'front.jpg'), frontBuffer);
      fs.writeFileSync(path.join(cinDir, 'back.jpg'), backBuffer);

      const baseUrl =
        process.env.PUBLIC_BACKEND_URL ||
        process.env.BASE_URL ||
        'http://localhost:3000';
      const cinFrontPhotoUrl = `${baseUrl}/uploads/cin-images/${userId}/front.jpg`;
      const cinBackPhotoUrl = `${baseUrl}/uploads/cin-images/${userId}/back.jpg`;

      // Store successful CIN verification

      await this.identityVerificationService.storeCINVerification(
        userId,

        cinFrontPhotoUrl,

        cinBackPhotoUrl,

        frontExtractedCIN || '',

        'VERIFIED',
      );

      return {
        success: true,

        message:
          'CIN verification successful. Please proceed to face verification.',

        step: 'CIN_VERIFICATION',

        details: {
          extractedCIN: frontExtractedCIN || undefined,

          confidence: dto.ocrVerified ? 1.0 : 0.5,
        },
      };
    } catch (error) {
      this.logger.error(`CIN verification error for user ${userId}:`, error);

      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new BadRequestException({
        message: 'CIN verification failed. Please try again.',

        step: 'CIN_VERIFICATION',
      });
    }
  }

  /**

   * Step 2: Verify face through liveness detection and face recognition

   * POST /livreur/verify/face

   */

  @Post('face')
  async verifyFace(
    @Req() req: ReqWithUser,

    @Body() dto: VerifyFaceDto,
  ): Promise<IdentityVerificationResponseDto> {
    const userId = req.user.sub;

    // Require a valid consumed liveness session — blocks direct bypass
    if (!dto.livenessSessionId) {
      throw new BadRequestException(
        'Liveness verification must be completed first.',
      );
    }
    if (
      !this.livenessSessionService.isSessionConsumed(
        dto.livenessSessionId,
        userId,
      )
    ) {
      this.logger.warn(
        `[FaceVerify] User ${userId} provided invalid/unconsumed session: ${dto.livenessSessionId}`,
      );
      throw new BadRequestException(
        'Liveness verification must be completed first. Please complete the liveness challenge.',
      );
    }

    try {
      // Get the user's stored CIN front photo

      const profile = await this.livreurService.getLivreurProfile(userId);

      if ((profile as any).cinVerificationStatus !== 'VERIFIED') {
        throw new BadRequestException(
          'CIN verification must be completed first. Please verify your CIN.',
        );
      }

      // Prefer base64 sent directly from client; fall back to reading file from disk
      let cinImageForComparison = dto.cinFrontImageBase64 || '';
      if (!cinImageForComparison && profile.cinFrontPhotoUrl) {
        // Extract file path from URL and read from disk
        try {
          const urlPath = new URL(profile.cinFrontPhotoUrl).pathname; // e.g. /uploads/cin-images/.../front.jpg
          const filePath = path.join(process.cwd(), urlPath);
          if (fs.existsSync(filePath)) {
            const fileBuffer = fs.readFileSync(filePath);
            cinImageForComparison = `data:image/jpeg;base64,${fileBuffer.toString('base64')}`;
            this.logger.log(`Read CIN image from disk: ${filePath}`);
          }
        } catch (e: any) {
          this.logger.warn(`Could not read CIN image from disk: ${e.message}`);
        }
      }

      const faceRecognitionResult =
        await this.identityVerificationService.performFaceRecognition(
          dto.selfieImageBase64,

          cinImageForComparison,

          dto.faceMatch, // Client-side verification result from ML Kit
        );

      // Trust the face service's match decision (it uses its own threshold internally)

      if (!faceRecognitionResult.isMatch) {
        throw new BadRequestException({
          message: `Face recognition failed. Match score: ${(faceRecognitionResult.matchScore * 100).toFixed(1)}%. Please try again.`,

          step: 'FACE_VERIFICATION',
        });
      }

      // Complete identity verification

      await this.identityVerificationService.completeIdentityVerification(
        userId,

        profile.cinFrontPhotoUrl || '',

        profile.cinBackPhotoUrl || '',
      );

      return {
        success: true,

        message: 'Identity verification completed successfully!',

        step: 'COMPLETED',

        details: {
          matchScore: faceRecognitionResult.matchScore,

          confidence: 1.0, // liveness already verified via consumed session
        },
      };
    } catch (error) {
      this.logger.error(`Face verification error for user ${userId}:`, error);

      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new BadRequestException({
        message: 'Face verification failed. Please try again.',

        step: 'FACE_VERIFICATION',
      });
    }
  }

  /**
   * Issue a liveness session (must be called before verification).
   * POST /livreur/verify/liveness/session
   */
  @Post('liveness/session')
  async issueLivenessSession(@Req() req: ReqWithUser) {
    const userId = req.user.sub;
    const session = this.livenessSessionService.issueSession(userId);
    this.logger.log(
      `[Liveness] Session issued for user ${userId}: ${session.sessionId}`,
    );
    return session;
  }

  /**
   * Liveness verification with challenge-response + session validation
   * POST /livreur/verify/liveness
   */
  @Post('liveness')
  async verifyLiveness(
    @Req() req: ReqWithUser,
    @Body() dto: LivenessVerifyDto,
  ) {
    const userId = req.user.sub;
    this.logger.log(
      `[Liveness] Challenges ${JSON.stringify(dto.challenges)} from user ${userId} with ${dto.frames.length} frames, ${dto.telemetry?.length || 0} telemetry`,
    );

    try {
      // 0. Validate session (replay protection)
      if (!dto.sessionId || !dto.nonce) {
        throw new BadRequestException('Missing session credentials');
      }

      const sessionCheck = this.livenessSessionService.validateSession(
        dto.sessionId,
        dto.nonce,
        userId,
      );
      if (!sessionCheck.valid) {
        return {
          success: false,
          isLive: false,
          confidence: 0,
          reason: sessionCheck.error,
          riskLevel: 'HIGH',
        };
      }

      // Use server-authoritative challenges (ignore client-sent challenges)
      const serverChallenges = this.livenessSessionService.getSessionChallenges(
        dto.sessionId,
      );
      if (!serverChallenges) {
        throw new BadRequestException('Session challenges not found');
      }

      // Replay detection: hash payload
      const payloadHash = createHash('sha256')
        .update(
          dto.sessionId +
            dto.nonce +
            dto.frames.length +
            (dto.telemetry?.length || 0),
        )
        .digest('hex');

      if (this.livenessSessionService.isReplay(payloadHash)) {
        return {
          success: false,
          isLive: false,
          confidence: 0,
          reason: 'Replay attack detected',
          riskLevel: 'HIGH',
        };
      }

      // 1. Call Python liveness service with frames + telemetry (server validates everything)
      const livenessResult =
        await this.identityVerificationService.performLivenessVerification(
          dto.frames,
          serverChallenges, // use SERVER challenges, not client-sent
          dto.telemetry,
        );

      if (!livenessResult.isLive) {
        return {
          success: false,
          isLive: false,
          confidence: livenessResult.confidence,
          riskLevel: livenessResult.riskLevel,
          reason: livenessResult.reason,
          checks: livenessResult.checks,
        };
      }

      // Session consumed + payload registered (prevents replay)
      this.livenessSessionService.consumeSession(dto.sessionId);
      this.livenessSessionService.registerPayload(payloadHash);

      // 2. If liveness passed, also do face comparison with CIN
      let faceMatch = { isMatch: false, matchScore: 0 };
      const profile = await this.livreurService.getLivreurProfile(userId);

      // Resolve CIN image: from DTO, or read from disk
      let cinImage = dto.cinFrontImageBase64 || '';
      if (!cinImage && profile.cinFrontPhotoUrl) {
        try {
          const urlPath = new URL(profile.cinFrontPhotoUrl).pathname;
          const filePath = path.join(process.cwd(), urlPath);
          if (fs.existsSync(filePath)) {
            const fileBuffer = fs.readFileSync(filePath);
            cinImage = `data:image/jpeg;base64,${fileBuffer.toString('base64')}`;
          }
        } catch (e: any) {
          this.logger.warn(`Could not read CIN from disk: ${e.message}`);
        }
      }

      if (cinImage && dto.selfieImageBase64) {
        // Sample 3 frames across the session for more robust face matching
        const frameCount = dto.frames.length;
        const sampleIndices = [0, Math.floor(frameCount / 2), frameCount - 1];

        this.logger.log(
          `[Liveness] Sampling frames ${sampleIndices.join(', ')} for face comparison`,
        );

        const faceResults = await Promise.all(
          sampleIndices.map((idx) =>
            this.identityVerificationService.performFaceRecognition(
              `data:image/jpeg;base64,${dto.frames[idx]}`,
              cinImage,
            ),
          ),
        );

        // Require majority match (at least 2 out of 3)
        const matchCount = faceResults.filter((r) => r.isMatch).length;
        const avgScore =
          faceResults.reduce((sum, r) => sum + r.matchScore, 0) /
          faceResults.length;

        faceMatch = {
          isMatch: matchCount >= 2,
          matchScore: avgScore,
        };

        this.logger.log(
          `[Liveness] Face comparison: ${matchCount}/3 matches, avg_score=${avgScore.toFixed(3)}, final_match=${faceMatch.isMatch}`,
        );
      }

      // 3. If face matched, complete identity verification
      if (faceMatch.isMatch) {
        await this.identityVerificationService.completeIdentityVerification(
          userId,
          profile.cinFrontPhotoUrl || '',
          profile.cinBackPhotoUrl || '',
        );
      }

      return {
        success: faceMatch.isMatch,
        isLive: true,
        confidence: livenessResult.confidence,
        riskLevel: livenessResult.riskLevel,
        reason: livenessResult.reason,
        checks: livenessResult.checks,
        faceMatch: faceMatch.isMatch,
        matchScore: faceMatch.matchScore,
      };
    } catch (error) {
      this.logger.error(`[Liveness] Error for user ${userId}:`, error);
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException(
        'Liveness verification failed. Please try again.',
      );
    }
  }

  /**

   * Compare faces between CIN photo and selfie for real-time verification

   * POST /livreur/verify/compare-faces

   */

  @Post('compare-faces')
  async compareFaces(
    @Req() req: ReqWithUser,

    @Body() dto: { cinImageBase64: string; selfieImageBase64: string },
  ) {
    const userId = req.user.sub;

    this.logger.log(
      `[CompareFaces] Face comparison requested by user ${userId}`,
    );

    try {
      // Validate input

      if (!dto.cinImageBase64 || !dto.selfieImageBase64) {
        throw new BadRequestException(
          'Both CIN image and selfie image are required',
        );
      }

      // Perform face recognition comparison

      const result =
        await this.identityVerificationService.performFaceRecognition(
          dto.selfieImageBase64,

          dto.cinImageBase64,

          undefined, // No client-side match yet, we're doing the comparison
        );

      this.logger.log(
        `[CompareFaces] Match score: ${result.matchScore}, isMatch: ${result.isMatch}`,
      );

      return {
        matchScore: result.matchScore,

        isMatch: result.isMatch,

        threshold: 0.4,

        message: result.isMatch
          ? 'Face match successful'
          : 'Face does not match. Please ensure you are using your own ID card.',
      };
    } catch (error) {
      this.logger.error(`[CompareFaces] Error for user ${userId}:`, error);

      throw new BadRequestException(
        'Face verification service is temporarily unavailable. Please try again later.',
      );
    }
  }

  /**

   * Get current verification status

   * GET /livreur/verify/status

   */

  @Post('status')
  async getVerificationStatus(@Req() req: ReqWithUser) {
    const userId = req.user.sub;

    const profile = await this.livreurService.getLivreurProfile(userId);

    return {
      cinVerified: profile.cinVerificationStatus === 'VERIFIED',

      identityVerified: profile.identityVerified || false,

      cinVerifiedAt: profile.cinVerifiedAt,

      identityVerifiedAt: profile.identityVerifiedAt,
    };
  }
}
