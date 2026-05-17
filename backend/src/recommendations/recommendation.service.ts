import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmbeddingService } from './embedding.service';

interface ScoredOffer {
  offer: Record<string, any>;
  score: number;
  reasons: string[];

  primaryFactors?: string[];
  secondaryFactors?: string[];
  confidence?: 'LOW' | 'MEDIUM' | 'HIGH';
}

interface ClientSignals {
  cuisinePreferences: string[];
  orderedCategories: Map<string, number>;
  orderedRestaurants: Map<string, number>;
  orderedOfferIds: Set<string>;
  latitude: number | null;
  longitude: number | null;

  viewedCategories: Map<string, number>;
  viewedRestaurants: Map<string, number>;
  viewedOfferIds: Set<string>;

  avgOrderPrice: number | null;
  tasteVector: number[] | null;
}

const W = {
  COLLABORATIVE: 0.15, // users-who-ordered-similarly
  SEMANTIC: 0.25, // embedding cosine similarity
  CUISINE_PREF: 0.24, // explicit cuisine preferences
  VIEWED: 0.1, // viewed categories/restaurants
  PRICE: 0.1, // price proximity to user average
  PROXIMITY: 0.01, // geographic distance
  RATING: 0.1, // restaurant quality rating
  DISCOUNT: 0.05, // promotional discount
} as const;

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

@Injectable()
export class RecommendationService {
  private readonly logger = new Logger(RecommendationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly embeddingService: EmbeddingService,
  ) {}

  // =======================================================================
  // Interaction tracking (called from InteractionsController)
  // =======================================================================

  async trackOfferView(
    clientId: string,
    offerId: string,
    categories: string[],
    price: number | null,
  ): Promise<void> {
    try {
      await this.prisma.clientInteraction.create({
        data: {
          clientId,
          interactionType: 'OFFER_VIEW',
          offerId,
          categories,
          price,
        },
      });
    } catch (err) {
      this.logger.warn('Failed to track offer view', err);
    }
  }

  async trackRestaurantView(
    clientId: string,
    restaurantId: string,
  ): Promise<void> {
    try {
      await this.prisma.clientInteraction.create({
        data: {
          clientId,
          interactionType: 'RESTAURANT_VIEW',
          restaurantId,
        },
      });
    } catch (err) {
      this.logger.warn('Failed to track restaurant view', err);
    }
  }

  private buildExplanation(score: number, reasons: string[]) {
    const primaryFactors = reasons.slice(0, 3);
    const secondaryFactors = reasons.slice(3);

    let confidence: 'LOW' | 'MEDIUM' | 'HIGH' = 'LOW';

    if (score >= 0.7) confidence = 'HIGH';
    else if (score >= 0.4) confidence = 'MEDIUM';

    return {
      primaryFactors,
      secondaryFactors,
      confidence,
    };
  }

  // =======================================================================
  // Public API — Personalised recommendations
  // =======================================================================

  async getRecommendedOffers(
    clientId: string,
    limit = 50,
  ): Promise<ScoredOffer[]> {
    // 1. Fetch active offers
    const offers = await this.fetchActiveOffers();
    if (!offers.length) return [];

    const vec = await this.embeddingService.embed('test pizza pasta');
    console.log('EMBED RESULT:', vec);

    // 2. Build client signal profile
    const signals = await this.buildClientSignals(clientId);

    // 3. Compute collaborative scores (simple co-occurrence)
    const collaborativeScores = await this.computeCollaborativeScores(
      clientId,
      signals,
      offers,
    );

    // 4. Score every offer (order-independent)
    const scored = offers.map((offer) =>
      this.scoreOffer(offer, signals, collaborativeScores),
    );

    // 5. Sort descending by score
    scored.sort((a, b) => b.score - a.score);

    // 6. Apply diversity penalty (single-pass post-ranking adjustment)
    this.applyDiversityPenalty(scored, limit);

    // Logging
    this.logger.debug(
      `Recommendations for ${clientId}: ${offers.length} offers, collabSignals=${collaborativeScores.size}`,
    );

    // Return without embeddings and without scoreBreakdown (simplified for academic clarity)
    return scored.slice(0, limit).map(({ offer, score, reasons }, index) => {
      const { descriptionEmbedding: _emb, ...offerWithoutEmbedding } = offer;

      return {
        rank: index + 1,
        offer: offerWithoutEmbedding,
        score,
        reasons,
      };
    });
  }

  // -----------------------------------------------------------------------
  // Fetch active offers
  // -----------------------------------------------------------------------

  private async fetchActiveOffers() {
    return this.prisma.offer.findMany({
      where: {
        status: 'ACTIVE',
        quantity: { gt: 0 },
      },
      select: {
        id: true,
        description: true,
        descriptionEmbedding: true,
        originalPrice: true,
        discountedPrice: true,
        quantity: true,
        pickupTime: true,
        pickupDateTime: true,
        categories: true,
        restaurantId: true,
        createdAt: true,
        updatedAt: true,
        status: true,
        visibility: true,
        deliveryAvailable: true,
        photoUrl: true,
        restaurant: {
          select: {
            id: true,
            restaurantProfile: {
              select: {
                restaurantName: true,
                city: true,
                logoUrl: true,
                address: true,
                avgRating: true,
                latitude: true,
                longitude: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    }) as Promise<any[]>;
  }

  // -----------------------------------------------------------------------
  // Build client signal profile
  // -----------------------------------------------------------------------

  private async buildClientSignals(clientId: string): Promise<ClientSignals> {
    // --- Cuisine preferences from profile ---
    const profile = await this.prisma.clientProfile.findUnique({
      where: { userId: clientId },
      select: {
        cuisinePreferences: true,
        lastLatitude: true,
        lastLongitude: true,
      },
    });

    const cuisinePreferences: string[] = (profile?.cuisinePreferences ??
      []) as string[];

    // --- Past orders ---
    const orders = await this.prisma.order.findMany({
      where: {
        clientId,
        status: { in: ['CONFIRMED', 'READY', 'PICKED_UP', 'DELIVERED'] },
      },
      select: {
        offerId: true,
        restaurantId: true,
        total: true,
        offer: { select: { categories: true, descriptionEmbedding: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const orderedCategories = new Map<string, number>();
    const orderedRestaurants = new Map<string, number>();
    const orderedOfferIds = new Set<string>();
    let totalSpent = 0;

    for (const order of orders) {
      orderedOfferIds.add(order.offerId);
      orderedRestaurants.set(
        order.restaurantId,
        (orderedRestaurants.get(order.restaurantId) ?? 0) + 1,
      );
      totalSpent += order.total ?? 0;
      // Aggregate categories from order.offer.categories
      const orderCategories = (order as any).offer?.categories as
        | string[]
        | undefined;
      if (orderCategories && Array.isArray(orderCategories)) {
        for (const cat of orderCategories) {
          orderedCategories.set(cat, (orderedCategories.get(cat) ?? 0) + 1);
        }
      }
    }

    const avgOrderPrice = orders.length > 0 ? totalSpent / orders.length : null;

    // --- Semantic taste vector: average embedding of ordered offers ---
    const orderedEmbeddings: number[][] = orders
      .map(
        (o) => (o as any).offer?.descriptionEmbedding as number[] | undefined,
      )
      .filter((emb): emb is number[] => Array.isArray(emb) && emb.length > 0);

    const tasteVector = this.embeddingService.averageVectors(orderedEmbeddings);

    // --- Implicit interest: recent views (last 30 days, simple counts only) ---
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const interactions = await this.prisma.clientInteraction.findMany({
      where: {
        clientId,
        createdAt: { gte: thirtyDaysAgo },
      },
      select: {
        interactionType: true,
        offerId: true,
        restaurantId: true,
        categories: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });

    const viewedCategories = new Map<string, number>();
    const viewedRestaurants = new Map<string, number>();
    const viewedOfferIds = new Set<string>();

    // Simple count-based accumulation (no time decay for academic clarity)
    for (const interaction of interactions) {
      if (interaction.interactionType === 'OFFER_VIEW' && interaction.offerId) {
        viewedOfferIds.add(interaction.offerId);
        for (const cat of interaction.categories ?? []) {
          viewedCategories.set(cat, (viewedCategories.get(cat) ?? 0) + 1);
        }
      }
      if (interaction.restaurantId) {
        viewedRestaurants.set(
          interaction.restaurantId,
          (viewedRestaurants.get(interaction.restaurantId) ?? 0) + 1,
        );
      }
    }

    return {
      cuisinePreferences,
      orderedCategories,
      orderedRestaurants,
      orderedOfferIds,
      latitude: profile?.lastLatitude ?? null,
      longitude: profile?.lastLongitude ?? null,
      viewedCategories,
      viewedRestaurants,
      viewedOfferIds,
      avgOrderPrice,
      tasteVector,
    };
  }

  // -----------------------------------------------------------------------
  // Collaborative filtering (AI)
  // -----------------------------------------------------------------------

  private async computeCollaborativeScores(
    clientId: string,
    signals: ClientSignals,
    activeOffers: { id: string }[],
  ): Promise<Map<string, number>> {
    const scores = new Map<string, number>();

    // Use both ordered AND viewed offers as seed for finding similar clients
    const seedOfferIds = new Set([
      ...signals.orderedOfferIds,
      ...signals.viewedOfferIds,
    ]);

    if (seedOfferIds.size === 0) return scores;

    // Find clients who ordered the same offers (exclude self)
    const similarClientOrders = await this.prisma.order.findMany({
      where: {
        offerId: { in: [...seedOfferIds] },
        clientId: { not: clientId },
        status: { in: ['CONFIRMED', 'READY', 'PICKED_UP', 'DELIVERED'] },
      },
      select: { clientId: true },
      distinct: ['clientId'],
      take: 100,
    });

    const similarClientIds = similarClientOrders.map((o) => o.clientId);
    if (!similarClientIds.length) return scores;

    // Find what those similar clients also ordered
    const theirOrders = await this.prisma.order.findMany({
      where: {
        clientId: { in: similarClientIds },
        status: { in: ['CONFIRMED', 'READY', 'PICKED_UP', 'DELIVERED'] },
      },
      select: { offerId: true },
    });

    const activeOfferIds = new Set(activeOffers.map((o) => o.id));

    for (const o of theirOrders) {
      if (
        activeOfferIds.has(o.offerId) &&
        !signals.orderedOfferIds.has(o.offerId)
      ) {
        scores.set(o.offerId, (scores.get(o.offerId) ?? 0) + 1);
      }
    }

    return scores;
  }

  // -----------------------------------------------------------------------
  // Score an individual offer (academic simplified version)
  // -----------------------------------------------------------------------

  private scoreOffer(
    offer: Record<string, any>,
    signals: ClientSignals,
    collaborativeScores: Map<string, number>,
  ): ScoredOffer {
    let score = 0;
    const reasons: string[] = [];

    const categories: string[] = (offer.categories ?? []) as string[];
    const restaurantId = offer.restaurantId as string;
    const restaurantProfile = (offer as any).restaurant?.restaurantProfile;

    // Simple threshold for including a reason (contribution > 5% of its weight)
    const REASON_THRESHOLD = 0.05;

    // ---- 1. COLLABORATIVE FILTERING ----
    const collabRaw = collaborativeScores.get(offer.id as string) ?? 0;
    if (collabRaw > 0) {
      // Simple normalization: count / (count + 5)
      const collabScore = collabRaw / (collabRaw + 5);
      score += W.COLLABORATIVE * collabScore;
      if (collabScore > REASON_THRESHOLD)
        reasons.push('Popular with similar customers');
    }

    // ---- 2. SEMANTIC SIMILARITY ----
    const offerEmbedding: number[] | undefined = (offer as any)
      .descriptionEmbedding;
    const hasValidEmbedding =
      Array.isArray(offerEmbedding) && offerEmbedding.length > 0;

    if (signals.tasteVector && hasValidEmbedding) {
      // Cosine similarity normalized to [0,1]
      const similarity = this.embeddingService.cosineSimilarity(
        signals.tasteVector,
        offerEmbedding,
      );
      const normSim = (similarity + 1) / 2;
      score += W.SEMANTIC * normSim;
      if (normSim > 0.7) reasons.push('Matches your taste profile');
    } else if (signals.tasteVector && !hasValidEmbedding) {
      // Simple fallback: ordered category overlap (capped at 0.5)
      const orderedOverlap = categories.filter((c) =>
        signals.orderedCategories.has(c),
      ).length;
      if (categories.length > 0) {
        const fallbackScore = Math.min(orderedOverlap / categories.length, 0.5);
        score += W.SEMANTIC * fallbackScore; // Use same weight slot
      }
    }

    // ---- 3. CUISINE PREFERENCES ----
    const prefMatches = categories.filter((c) =>
      signals.cuisinePreferences.includes(c),
    );
    if (prefMatches.length > 0 && signals.cuisinePreferences.length > 0) {
      const matchRatio = prefMatches.length / signals.cuisinePreferences.length;
      score += W.CUISINE_PREF * Math.min(matchRatio, 1);
      if (matchRatio > REASON_THRESHOLD)
        reasons.push(`Matches preferences: ${prefMatches.join(', ')}`);
    }

    // ---- 4. VIEWED CATEGORIES (simple count-based) ----
    let viewCount = 0;
    for (const cat of categories) {
      viewCount += signals.viewedCategories.get(cat) ?? 0;
    }
    if (viewCount > 0) {
      // Binary boost: any views = full weight contribution
      score += W.VIEWED * Math.min(viewCount / 3, 1); // Max at 3 views
      if (viewCount >= 2) reasons.push('Based on your browsing');
    }

    // ---- 5. PRICE SENSITIVITY ----
    if (signals.avgOrderPrice != null) {
      const offerPrice = (offer.discountedPrice as number) ?? 0;
      if (offerPrice > 0) {
        const diff = Math.abs(offerPrice - signals.avgOrderPrice);
        const range = Math.max(signals.avgOrderPrice * 0.5, 1);
        const priceScore = Math.max(0, 1 - diff / range);
        score += W.PRICE * priceScore;
        if (priceScore > 0.7) reasons.push('In your price range');
      }
    }

    // ---- 6. PROXIMITY ----
    if (
      signals.latitude != null &&
      signals.longitude != null &&
      restaurantProfile?.latitude != null &&
      restaurantProfile?.longitude != null
    ) {
      const distKm = this.haversineKm(
        signals.latitude,
        signals.longitude,
        restaurantProfile.latitude,
        restaurantProfile.longitude,
      );
      const proxScore = Math.max(0, 1 - distKm / 20);
      score += W.PROXIMITY * proxScore;
      if (distKm <= 5) reasons.push('Nearby');
    }

    // ---- 7. RATING ----
    const avgRating = (restaurantProfile?.avgRating as number) ?? 0;
    if (avgRating > 0) {
      const ratingScore = avgRating / 5;
      score += W.RATING * ratingScore;
      if (avgRating >= 4) reasons.push('Highly rated');
    }

    // ---- 8. DISCOUNT ----
    const original = (offer.originalPrice as number) ?? 0;
    const discounted = (offer.discountedPrice as number) ?? 0;
    if (original > 0) {
      const discountScore = (original - discounted) / original;
      score += W.DISCOUNT * discountScore;
      if (discountScore >= 0.4) reasons.push('Great deal');
    }

    // ---- NEGATIVE SIGNALS (simplified flat penalties) ----
    let penalty = 0;

    // 1. Distance > 15km → -0.1
    if (
      signals.latitude != null &&
      signals.longitude != null &&
      restaurantProfile?.latitude != null &&
      restaurantProfile?.longitude != null
    ) {
      const distKm = this.haversineKm(
        signals.latitude,
        signals.longitude,
        restaurantProfile.latitude,
        restaurantProfile.longitude,
      );
      if (distKm > 15) penalty += 0.1;
    }

    // 2. Price > 2x average → -0.1
    if (signals.avgOrderPrice != null && signals.avgOrderPrice > 0) {
      const offerPrice = (offer.discountedPrice as number) ?? 0;
      if (offerPrice > signals.avgOrderPrice * 2) penalty += 0.1;
    }

    // 3. Viewed but never ordered (≥3 views, 0 orders) → -0.05
    const views = signals.viewedRestaurants.get(restaurantId) ?? 0;
    const orders = signals.orderedRestaurants.get(restaurantId) ?? 0;
    if (views >= 3 && orders === 0) penalty += 0.05;

    // Apply penalties (capped at 0.2 total)
    score *= 1 - Math.min(penalty, 0.2);

    // Final bounds and NaN protection
    score = Math.max(0, Math.min(1, score));
    if (Number.isNaN(score)) score = 0;

    this.logger.debug(`
=== SCORE BREAKDOWN for offer ${offer.id} ===
tasteVector: ${signals.tasteVector ? 'EXISTS' : 'NULL'}
avgOrderPrice: ${signals.avgOrderPrice}
userLat: ${signals.latitude}, userLon: ${signals.longitude}
restaurantLat: ${restaurantProfile?.latitude}, restaurantLon: ${restaurantProfile?.longitude}
cuisinePrefs: ${signals.cuisinePreferences}
offerCategories: ${categories}
prefMatches: ${categories.filter((c) => signals.cuisinePreferences.includes(c))}
viewCount: ${viewCount}
orderedCategories: ${JSON.stringify([...signals.orderedCategories.entries()])}
collabRaw: ${collaborativeScores.get(offer.id as string) ?? 0}
hasEmbedding: ${hasValidEmbedding}
FINAL SCORE: ${score}
`);

    return { offer, score: Math.round(score * 1000) / 1000, reasons };
  }

  // -----------------------------------------------------------------------
  // Diversity re-ranking: apply additional penalty after initial sort
  // -----------------------------------------------------------------------

  private applyDiversityPenalty(scored: ScoredOffer[], topN: number): void {
    // Track restaurant frequency in top N results
    const restaurantCount = new Map<string, number>();
    const diversityFactor = 0.15; // 15% penalty per duplicate

    for (let i = 0; i < Math.min(scored.length, topN * 2); i++) {
      const offer = scored[i].offer as any;
      const restaurantId = offer.restaurantId as string;
      const count = restaurantCount.get(restaurantId) ?? 0;

      if (count > 0 && i < topN) {
        // Apply penalty only to top N results
        const penalty = Math.min(count * diversityFactor, 0.4); // Max 40% penalty
        scored[i].score *= 1 - penalty;
      }

      restaurantCount.set(restaurantId, count + 1);
    }

    // Re-sort after diversity adjustment
    scored.sort((a, b) => b.score - a.score);
  }

  // -----------------------------------------------------------------------
  // Util — Haversine distance in km
  // -----------------------------------------------------------------------

  private haversineKm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(a));
  }
}
