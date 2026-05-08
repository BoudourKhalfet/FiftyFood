import { Module } from '@nestjs/common';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';
import { RecommendationModule } from '../recommendations/recommendation.module';
import { PrismaService } from '../prisma/prisma.service';

@Module({
  imports: [RecommendationModule],
  controllers: [OffersController],
  providers: [OffersService, PrismaService],
  exports: [OffersService],
})
export class OffersModule {}
