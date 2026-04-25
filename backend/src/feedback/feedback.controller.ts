import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport/dist/auth.guard';
import { Role } from '@prisma/client';
import { FeedbackService } from './feedback.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { CreateComplaintDto } from './dto/create-complaint.dto';
import { CreateRestaurantReviewDto } from './dto/create-restaurant-review.dto';

@Controller('feedback')
@UseGuards(AuthGuard('jwt'))
export class FeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  @Post('reviews')
  async submitReview(@Req() req: Request, @Body() dto: CreateReviewDto) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.CLIENT) {
      throw new ForbiddenException('Only clients can submit reviews');
    }
    return this.feedbackService.submitReview(user.id, dto);
  }

  @Post('reviews/restaurant')
  async submitRestaurantReview(
    @Req() req: Request,
    @Body() dto: CreateRestaurantReviewDto,
  ) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.CLIENT) {
      throw new ForbiddenException('Only clients can submit reviews');
    }
    return this.feedbackService.submitRestaurantReview(user.id, dto);
  }

  @Post('complaints')
  async submitComplaint(@Req() req: Request, @Body() dto: CreateComplaintDto) {
    const user = req.user as { id: string; role: Role };
    if (user.role !== Role.CLIENT) {
      throw new ForbiddenException('Only clients can submit complaints');
    }
    return this.feedbackService.submitComplaint(user.id, dto);
  }

  @Get('received/reviews')
  async receivedReviews(@Req() req: Request, @Query('limit') limit?: string) {
    const user = req.user as { id: string; role: Role };
    const parsedLimit = Math.min(
      Math.max(parseInt(limit ?? '20', 10) || 20, 1),
      100,
    );
    return this.feedbackService.getReceivedReviews(
      user.id,
      user.role,
      parsedLimit,
    );
  }

  @Get('received/complaints')
  async receivedComplaints(
    @Req() req: Request,
    @Query('limit') limit?: string,
  ) {
    const user = req.user as { id: string; role: Role };
    const parsedLimit = Math.min(
      Math.max(parseInt(limit ?? '20', 10) || 20, 1),
      100,
    );
    return this.feedbackService.getReceivedComplaints(
      user.id,
      user.role,
      parsedLimit,
    );
  }
}
