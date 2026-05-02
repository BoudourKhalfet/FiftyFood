import { Body, Controller, Post, Req } from '@nestjs/common';
import { RecommendationService } from './recommendation.service';

type ReqWithUser = { user: { sub: string } };

@Controller('interactions')
export class InteractionsController {
  constructor(private readonly recommendations: RecommendationService) {}

  @Post('offer-view')
  async trackOfferView(
    @Req() req: ReqWithUser,
    @Body() body: { offerId: string; categories?: string[]; price?: number },
  ) {
    await this.recommendations.trackOfferView(
      req.user.sub,
      body.offerId,
      body.categories ?? [],
      body.price ?? null,
    );
    return { tracked: true };
  }

  @Post('restaurant-view')
  async trackRestaurantView(
    @Req() req: ReqWithUser,
    @Body() body: { restaurantId: string },
  ) {
    await this.recommendations.trackRestaurantView(
      req.user.sub,
      body.restaurantId,
    );
    return { tracked: true };
  }
}
