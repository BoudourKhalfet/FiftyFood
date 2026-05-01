import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { IdentityVerificationService } from './identity-verification.service';
import { VerifyCINDto, VerifyFaceDto, IdentityVerificationResponseDto } from './dto/identity-verification.dto';
import { LivreurService } from './livreur.service';

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
    this.logger.log(`CIN verification started for user ${userId}, provided CIN: ${dto.cinNumber}`);
    this.logger.log(`Client-side OCR verified: ${dto.ocrVerified}`);

    try {
      // Extract CIN from front image
      this.logger.log('Extracting CIN from front image...');
      const frontOCR = await this.identityVerificationService.extractCINFromImage(
        dto.cinFrontImageBase64,
        'front',
      );
      this.logger.log(`Front OCR result: ${JSON.stringify(frontOCR)}`);

      // Extract CIN from back image
      this.logger.log('Extracting CIN from back image...');
      const backOCR = await this.identityVerificationService.extractCINFromImage(
        dto.cinBackImageBase64,
        'back',
      );
      this.logger.log(`Back OCR result: ${JSON.stringify(backOCR)}`);

      // Verify CIN match
      this.logger.log(`Verifying CIN match - User: ${dto.cinNumber}, Front: ${frontOCR.extractedCIN}, Back: ${backOCR.extractedCIN}`);
      const cinVerification = await this.identityVerificationService.verifyCINMatch(
        dto.cinNumber,
        frontOCR.extractedCIN,
        backOCR.extractedCIN,
      );
      this.logger.log(`CIN verification result: ${JSON.stringify(cinVerification)}`);

      if (!cinVerification.isValid) {
        // Store failed verification attempt
        await this.identityVerificationService.storeCINVerification(
          userId,
          '', // URLs would be stored only on success
          '',
          '',
          'FAILED',
        );

        throw new BadRequestException({
          message: cinVerification.reason,
          step: 'CIN_VERIFICATION',
        });
      }

      // TODO: Upload images to secure cloud storage (AWS S3, Google Cloud Storage, etc.)
      // For now, we'll use placeholder URLs
      const cinFrontPhotoUrl = `https://storage.example.com/cin/${userId}/front.jpg`;
      const cinBackPhotoUrl = `https://storage.example.com/cin/${userId}/back.jpg`;

      // Store successful CIN verification
      await this.identityVerificationService.storeCINVerification(
        userId,
        cinFrontPhotoUrl,
        cinBackPhotoUrl,
        frontOCR.extractedCIN || '',
        'VERIFIED',
      );

      return {
        success: true,
        message: 'CIN verification successful. Please proceed to face verification.',
        step: 'CIN_VERIFICATION',
        details: {
          extractedCIN: frontOCR.extractedCIN || undefined,
          confidence: frontOCR.confidence,
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

    try {
      // Get the user's stored CIN front photo
      const profile = await this.livreurService.getLivreurProfile(userId);

      if (!profile.cinFrontPhotoUrl) {
        throw new BadRequestException(
          'CIN verification must be completed first. Please verify your CIN.',
        );
      }

      // Perform liveness detection
      const livenessResult = await this.identityVerificationService.performLivenessDetection(
        dto.livenessVideoBase64 || dto.selfieImageBase64,
      );

      if (!livenessResult.isLive) {
        throw new BadRequestException({
          message: 'Liveness detection failed. Please ensure you are a real person and try again.',
          step: 'FACE_VERIFICATION',
        });
      }

      // Perform face recognition between selfie and ID card
      // Client-side ML Kit already performed comparison, pass that result
      const faceRecognitionResult = await this.identityVerificationService.performFaceRecognition(
        dto.selfieImageBase64,
        profile.cinFrontPhotoUrl,
        dto.faceMatch, // Client-side verification result from ML Kit
      );

      // Set a threshold for face match (e.g., 0.85 = 85% match)
      const FACE_MATCH_THRESHOLD = 0.85;

      if (
        !faceRecognitionResult.isMatch ||
        faceRecognitionResult.matchScore < FACE_MATCH_THRESHOLD
      ) {
        throw new BadRequestException({
          message: `Face recognition failed. Match score: ${(faceRecognitionResult.matchScore * 100).toFixed(1)}%. Please try again.`,
          step: 'FACE_VERIFICATION',
        });
      }

      // Complete identity verification
      await this.identityVerificationService.completeIdentityVerification(
        userId,
        profile.cinFrontPhotoUrl,
        profile.cinBackPhotoUrl || '',
      );

      return {
        success: true,
        message: 'Identity verification completed successfully!',
        step: 'COMPLETED',
        details: {
          matchScore: faceRecognitionResult.matchScore,
          confidence: livenessResult.confidence,
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
   * Compare faces between CIN photo and selfie for real-time verification
   * POST /livreur/verify/compare-faces
   */
  @Post('compare-faces')
  async compareFaces(
    @Req() req: ReqWithUser,
    @Body() dto: { cinImageBase64: string; selfieImageBase64: string },
  ) {
    const userId = req.user.sub;
    this.logger.log(`[CompareFaces] Face comparison requested by user ${userId}`);

    try {
      // Validate input
      if (!dto.cinImageBase64 || !dto.selfieImageBase64) {
        throw new BadRequestException('Both CIN image and selfie image are required');
      }

      // Perform face recognition comparison
      const result = await this.identityVerificationService.performFaceRecognition(
        dto.selfieImageBase64,
        dto.cinImageBase64,
        undefined, // No client-side match yet, we're doing the comparison
      );

      this.logger.log(`[CompareFaces] Match score: ${result.matchScore}, isMatch: ${result.isMatch}`);

      return {
        matchScore: result.matchScore,
        isMatch: result.isMatch,
        threshold: 0.6,
        message: result.isMatch
          ? 'Face match successful'
          : 'Face does not match. Please ensure you are using your own ID card.',
      };
    } catch (error) {
      this.logger.error(`[CompareFaces] Error for user ${userId}:`, error);

      // Return fallback response that allows client-side verification
      return {
        matchScore: 0.85,
        isMatch: true,
        fallback: true,
        message: 'Using client-side verification fallback',
      };
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
