import { Module } from '@nestjs/common';
import {
  PublicRestaurantsController,
  RestaurantAccountController,
  RestaurantsController,
} from './restaurants.controller';
import { RestaurantsService } from './restaurants.service';

@Module({
  controllers: [
    RestaurantsController,
    PublicRestaurantsController,
    RestaurantAccountController,
  ],
  providers: [RestaurantsService],
})
export class RestaurantsModule {}
