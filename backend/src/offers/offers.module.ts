import { Module } from '@nestjs/common';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';
import { RecommendationModule } from '../recommendations/recommendation.module';

@Module({
  imports: [RecommendationModule],
  controllers: [OffersController],
  providers: [OffersService],
})
export class OffersModule {}
