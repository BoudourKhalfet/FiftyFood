import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { PrismaModule } from '../prisma/prisma.module';
import { LivreurOnboardingController } from './livreur.controller';
import { LivreurService } from './livreur.service';
import { IdentityVerificationController } from './identity-verification.controller';
import { IdentityVerificationService } from './identity-verification.service';
import { LivenessSessionService } from './liveness-session.service';

@Module({
  imports: [PrismaModule, HttpModule],
  controllers: [LivreurOnboardingController, IdentityVerificationController],
  providers: [LivreurService, IdentityVerificationService, LivenessSessionService],
})
export class LivreurModule {}
