import { Module } from '@nestjs/common';
import { RecommendationService } from './recommendation.service';
import { InteractionsController } from './interactions.controller';
import { EmbeddingService } from './embedding.service';

@Module({
  controllers: [InteractionsController],
  providers: [RecommendationService, EmbeddingService],
  exports: [RecommendationService, EmbeddingService],
})
export class RecommendationModule {}
