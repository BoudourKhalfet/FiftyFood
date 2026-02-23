import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { ProfileCompleteGuard } from './auth/profile-complete.guard';
import { RestaurantsModule } from './restaurants/restaurants.module';
@Module({
  imports: [PrismaModule, AuthModule, UsersModule, RestaurantsModule],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: ProfileCompleteGuard,
    },
  ],
})
export class AppModule {}
