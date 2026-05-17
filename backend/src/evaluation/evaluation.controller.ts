import { Controller, Post, Body, Logger } from '@nestjs/common';
import { EvaluationService } from './evaluation.service';

interface EvaluationRequest {
  k?: number;
}

/**
 * Thin controller (correct architecture)
 * - No logic
 * - No mapping
 * - No duplication
 */

@Controller('evaluation')
export class EvaluationController {
  private readonly logger = new Logger(EvaluationController.name);

  constructor(private readonly evaluationService: EvaluationService) {}

  @Post('run')
  async runEvaluation(@Body() body?: EvaluationRequest) {
    const k = body?.k ?? 10;

    this.logger.log(`Running evaluation (K=${k})`);

    return this.evaluationService.runEvaluation(k);
  }
}
