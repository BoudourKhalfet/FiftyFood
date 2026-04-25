import { Module } from '@nestjs/common';
import { FeedbackController } from 'src/feedback/feedback.controller';
import { FeedbackService } from 'src/feedback/feedback.service';

@Module({
  controllers: [FeedbackController],
  providers: [FeedbackService],
})
export class FeedbackModule {}
