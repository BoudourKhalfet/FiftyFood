import { Module } from '@nestjs/common';
import { EvaluationService } from './evaluation.service';
import { EvaluationController } from './evaluation.controller';
import { RecommendationModule } from '../recommendations/recommendation.module';
import { PrismaModule } from '../prisma/prisma.module';

/**
 * Evaluation Module
 * 
 * Provides offline evaluation capabilities for the recommender system.
 * Imports RecommendationModule and PrismaModule to reuse existing services.
 */
@Module({
  imports: [RecommendationModule, PrismaModule],
  controllers: [EvaluationController],
  providers: [EvaluationService],
})
export class EvaluationModule {}
