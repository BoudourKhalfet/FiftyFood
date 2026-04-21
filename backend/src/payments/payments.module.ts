import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PayPalController } from './paypal.controller';
import { PaymentsService } from './payments.service';
import { StripeService } from './services/stripe.service';
import { KonnectService } from './services/konnect.service';
import { PayPalService } from './services/paypal.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [PaymentsController, PayPalController],
  providers: [PaymentsService, StripeService, KonnectService, PayPalService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
