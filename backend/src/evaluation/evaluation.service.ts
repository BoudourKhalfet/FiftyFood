import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RecommendationService } from '../recommendations/recommendation.service';

/**
 * OFFLINE RECOMMENDER EVALUATION (FINAL CLEAN VERSION)
 * - Synthetic users
 * - Rule-based pseudo ground truth
 * - Hybrid vs Random vs Popularity baselines
 */

const EVALUATION_SEED = 42;

// =========================
// TYPES
// =========================

interface SyntheticUser {
  id: string;
  preferredCategories: string[];
  maxPrice: number;
}

interface PseudoGroundTruth {
  relevantOfferIds: Set<string>;
}

interface SystemResult {
  precision: number;
  recall: number;
  relevantInTopK: number;
}

interface UserEvaluationResult {
  groundTruthSize: number;
  hybrid: SystemResult;
  random: SystemResult;
  popularity: SystemResult;
}

interface SystemMetrics {
  precisionAtK: number;
  recallAtK: number;
}

interface EvaluationResults {
  k: number;
  userCount: number;
  avgRelevantPerUser: number;

  hybrid: SystemMetrics;
  random: SystemMetrics;
  popularity: SystemMetrics;

  evaluationMethodology: {
    groundTruthType: string;
    randomBaselineType: string;
    popularityMetric: string;
    coldStart: boolean;
  };

  evaluationLimitations: {
    noHumanLabels: boolean;
    syntheticUsers: boolean;
    ruleBasedGroundTruth: boolean;
  };

  timestamp: string;
}

@Injectable()
export class EvaluationService {
  private readonly logger = new Logger(EvaluationService.name);

  constructor(
    private readonly recommendationService: RecommendationService,
    private readonly prisma: PrismaService,
  ) {}

  // =========================
  // MAIN PIPELINE
  // =========================

  async runEvaluation(k: number): Promise<EvaluationResults> {
    this.logger.log(`Evaluation started (K=${k})`);

    const users = this.generateSyntheticUsers(40);
    const offers = await this.fetchOffers();

    if (!offers.length) {
      throw new Error('No offers found for evaluation');
    }

    const popularity = await this.computePopularity();

    const results = await Promise.all(
      users.map(u => this.evaluateUser(u, k, offers, popularity)),
    );

    return this.aggregate(results, k);
  }

  // =========================
  // SYNTHETIC USERS
  // =========================

  private generateSyntheticUsers(count: number): SyntheticUser[] {
    const categories = [
      'Italian', 'Fast Food', 'Asian', 'Healthy',
      'Dessert', 'Bakery', 'Mexican', 'Indian',
    ];

    const prices = [8, 15, 25];

    return Array.from({ length: count }, (_, i) => {
      const seed = EVALUATION_SEED + i;

      return {
        id: `synthetic_${seed}`,
        preferredCategories: [
          categories[seed % categories.length],
          categories[(seed * 3) % categories.length],
        ],
        maxPrice: prices[seed % prices.length],
      };
    });
  }

  // =========================
  // DATA
  // =========================

  private async fetchOffers() {
    return this.prisma.offer.findMany({
      where: { status: 'ACTIVE', quantity: { gt: 0 } },
      select: {
        id: true,
        categories: true,
        discountedPrice: true,
      },
    });
  }

  private async computePopularity(): Promise<Map<string, number>> {
    const orders = await this.prisma.order.findMany({
      where: {
        status: { in: ['CONFIRMED', 'READY', 'PICKED_UP', 'DELIVERED'] },
      },
      select: { offerId: true },
    });

    const counts = new Map<string, number>();

    for (const o of orders) {
      counts.set(o.offerId, (counts.get(o.offerId) ?? 0) + 1);
    }

    const scores = new Map<string, number>();
    let max = 0;

    for (const [id, c] of counts.entries()) {
      const score = Math.log(1 + c);
      scores.set(id, score);
      max = Math.max(max, score);
    }

    for (const [id, s] of scores.entries()) {
      scores.set(id, max > 0 ? s / max : 0);
    }

    return scores;
  }

  // =========================
  // EVALUATION PER USER
  // =========================

  private async evaluateUser(
    user: SyntheticUser,
    k: number,
    offers: any[],
    popularity: Map<string, number>,
  ): Promise<UserEvaluationResult> {

    const gt = this.buildGroundTruth(user, offers);

    const hybrid = await this.getHybrid(user.id, k);
    const random = this.getRandom(offers, k, user.id);
    const pop = this.getPopularity(offers, k, popularity);

    return {
      groundTruthSize: gt.relevantOfferIds.size,
      hybrid: this.computeMetrics(hybrid, gt, k),
      random: this.computeMetrics(random, gt, k),
      popularity: this.computeMetrics(pop, gt, k),
    };
  }

  // =========================
  // GROUND TRUTH
  // =========================

  private buildGroundTruth(user: SyntheticUser, offers: any[]): PseudoGroundTruth {
    const relevant = new Set<string>();

    for (const o of offers) {
      const cats: string[] = o.categories ?? [];
      const price = o.discountedPrice ?? 0;

      const match =
        cats.some(c => user.preferredCategories.includes(c)) &&
        price <= user.maxPrice;

      if (match) relevant.add(o.id);
    }

    return { relevantOfferIds: relevant };
  }

  // =========================
  // BASELINES
  // =========================

  private async getHybrid(userId: string, k: number): Promise<string[]> {
    const recs = await this.recommendationService.getRecommendedOffers(userId, k);

    if (!recs?.length) return [];

    return recs.map(r => r.offer.id);
  }

  private getRandom(offers: any[], k: number, userId: string): string[] {
    const seed = this.seed(userId);
    const shuffled = this.shuffle([...offers], seed);
    return shuffled.slice(0, k).map(o => o.id);
  }

  private getPopularity(
    offers: any[],
    k: number,
    scores: Map<string, number>,
  ): string[] {
    return [...offers]
      .sort((a, b) => (scores.get(b.id) ?? 0) - (scores.get(a.id) ?? 0))
      .slice(0, k)
      .map(o => o.id);
  }

  // =========================
  // METRICS (FIXED)
  // =========================

  private computeMetrics(
    recs: string[],
    gt: PseudoGroundTruth,
    k: number,
  ): SystemResult {

    const topK = recs.slice(0, k);

    const relevant = topK.filter(id =>
      gt.relevantOfferIds.has(id),
    ).length;

    return {
      precision: k === 0 ? 0 : relevant / k,  // STRICT: always divide by K
      recall:
        gt.relevantOfferIds.size === 0
          ? 0
          : relevant / gt.relevantOfferIds.size,
      relevantInTopK: relevant,
    };
  }

  // =========================
  // AGGREGATION
  // =========================

  private aggregate(results: UserEvaluationResult[], k: number): EvaluationResults {

    const avg = (arr: number[]) =>
      arr.reduce((a, b) => a + b, 0) / arr.length;

    const pack = (key: keyof UserEvaluationResult) => ({
      precisionAtK: avg(results.map(r => (r[key] as SystemResult).precision)),
      recallAtK: avg(results.map(r => (r[key] as SystemResult).recall)),
    });

    return {
      k,
      userCount: results.length,
      avgRelevantPerUser: avg(results.map(r => r.groundTruthSize)),

      hybrid: pack('hybrid'),
      random: pack('random'),
      popularity: pack('popularity'),

      evaluationMethodology: {
        groundTruthType: 'rule-based',
        randomBaselineType: 'deterministic',
        popularityMetric: 'log-normalized orders',
        coldStart: true,
      },

      evaluationLimitations: {
        noHumanLabels: true,
        syntheticUsers: true,
        ruleBasedGroundTruth: true,
      },

      timestamp: new Date().toISOString(),
    };
  }

  // =========================
  // UTIL
  // =========================

  private seed(str: string): number {
    return (
      EVALUATION_SEED +
      str.split('').reduce((a, c) => a + c.charCodeAt(0), 0)
    );
  }

  private shuffle<T>(arr: T[], seed: number): T[] {
    let s = seed;

    const rand = () =>
      (s = (s * 9301 + 49297) % 233280) / 233280;

    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }

    return arr;
  }
}