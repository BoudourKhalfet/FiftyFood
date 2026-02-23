import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { LivreurOnboardingController } from './livreur.controller';
import { LivreurService } from './livreur.service';

@Module({
  imports: [PrismaModule],
  controllers: [LivreurOnboardingController],
  providers: [LivreurService],
})
export class LivreurModule {}
