import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmbeddingService } from './embedding.service';

/**
 * Hybrid Recommendation Engine
 *
 * Combines:
 * 1. Collaborative filtering (AI)  — "clients who ordered similar offers also liked …"
 * 2. Semantic similarity (NLP/AI)  — cosine similarity between client taste vector and offer embeddings
 * 3. Implicit interest tracking    — offer/restaurant views boost similar items
 * 4. Price sensitivity             — matches client's typical spending range
 * 5. Exploration factor            — surfaces unseen restaurants for discovery
 * 6. Rule-based scoring            — cuisine preferences, proximity, rating, discount
 *
 * Embeddings: sentence-transformers/all-MiniLM-L6-v2 via Hugging Face Inference API (free).
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ScoredOffer {
  offer: Record<string, any>;
  score: number;
  reasons: string[];
}

interface ClientSignals {
  cuisinePreferences: string[];
  orderedCategories: Map<string, number>;   // category → order count
  orderedRestaurants: Map<string, number>;  // restaurantId → order count
  orderedOfferIds: Set<string>;
  latitude: number | null;
  longitude: number | null;
  // Implicit interest signals
  viewedCategories: Map<string, number>;    // category → view count
  viewedRestaurants: Map<string, number>;   // restaurantId → view count
  viewedOfferIds: Set<string>;
  // Price sensitivity
  avgOrderPrice: number | null;
  // Semantic taste vector (average of ordered offer embeddings)
  tasteVector: number[] | null;
}

// ---------------------------------------------------------------------------
// Weights (tunable) — must sum to 1.0
// ---------------------------------------------------------------------------

const W = {
  // --- AI: collaborative filtering ---
  COLLABORATIVE:        0.20,  // item-based collaborative filtering
  // --- AI: semantic NLP similarity ---
  SEMANTIC_SIMILARITY:  0.16,  // cosine similarity between client taste vector and offer embedding
  // --- Order history category match ---
  HISTORY_CAT_MATCH:    0.06,  // offer category ∩ categories from past orders (log-weighted)
  // --- Implicit interest ---
  VIEWED_CATEGORY:      0.08,  // offer category matches recently viewed categories
  VIEWED_RESTAURANT:    0.07,  // offer from a restaurant the client browsed
  // --- Price sensitivity ---
  PRICE_MATCH:          0.07,  // offer price close to client's typical spending
  // --- Rule-based ---
  CUISINE_PREF_MATCH:   0.20,  // offer category ∩ client cuisinePreferences
  RESTAURANT_REPEAT:    0.05,  // client has ordered from this restaurant before
  PROXIMITY:            0.04,  // closer = higher
  RATING:               0.05,  // restaurant avgRating
  DISCOUNT:             0.01,  // higher discount % = higher
  // --- Exploration ---
  EXPLORATION:          0.01,  // subtle nudge for undiscovered restaurants
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

    // 2. Build client signal profile (orders + views + price)
    const signals = await this.buildClientSignals(clientId);

    // 3. Collaborative filtering: find offers liked by similar clients
    const collaborativeScores = await this.computeCollaborativeScores(
      clientId,
      signals,
      offers,
    );

    // 4. Score every offer
    const scored = offers.map((offer) =>
      this.scoreOffer(offer, signals, collaborativeScores),
    );

    // 5. Sort descending by score, cap at limit
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, limit).map(({ offer, score, reasons }) => {
      const { descriptionEmbedding: _emb, ...offerWithoutEmbedding } = offer;
      return { offer: offerWithoutEmbedding, score, reasons };
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
      include: {
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

    const cuisinePreferences: string[] = (profile?.cuisinePreferences ?? []) as string[];

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
      for (const cat of (order.offer?.categories ?? [])) {
        orderedCategories.set(cat, (orderedCategories.get(cat) ?? 0) + 1);
      }
    }

    const avgOrderPrice = orders.length > 0 ? totalSpent / orders.length : null;

    // --- Semantic taste vector: average embedding of ordered offers ---
    const orderedEmbeddings: number[][] = orders
      .map((o) => (o as any).offer?.descriptionEmbedding as number[] | undefined)
      .filter((v): v is number[] => Array.isArray(v) && v.length > 0);

    const tasteVector = this.embeddingService.averageVectors(orderedEmbeddings);

    // --- Implicit interest: recent views (last 30 days) ---
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

    for (const interaction of interactions) {
      if (interaction.interactionType === 'OFFER_VIEW' && interaction.offerId) {
        viewedOfferIds.add(interaction.offerId);
        for (const cat of (interaction.categories ?? [])) {
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
      if (activeOfferIds.has(o.offerId) && !signals.orderedOfferIds.has(o.offerId)) {
        scores.set(o.offerId, (scores.get(o.offerId) ?? 0) + 1);
      }
    }

    return scores;
  }

  // -----------------------------------------------------------------------
  // Score an individual offer
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

    // ---- COLLABORATIVE FILTERING (AI) ----
    const collabRaw = collaborativeScores.get(offer.id as string) ?? 0;
    if (collabRaw > 0) {
      const collabNorm = collabRaw / (collabRaw + 5);
      score += W.COLLABORATIVE * collabNorm;
      reasons.push('Popular with similar customers');
    }

    // ---- SEMANTIC SIMILARITY (NLP/AI) ----
    const offerEmbedding: number[] | undefined = (offer as any).descriptionEmbedding;
    if (
      signals.tasteVector &&
      Array.isArray(offerEmbedding) &&
      offerEmbedding.length > 0
    ) {
      const similarity = this.embeddingService.cosineSimilarity(
        signals.tasteVector,
        offerEmbedding,
      );
      // similarity ∈ [-1, 1] for MiniLM; normalise to [0, 1]
      const normSim = (similarity + 1) / 2;
      score += W.SEMANTIC_SIMILARITY * normSim;
      if (normSim >= 0.75) reasons.push('Closely matches your taste profile');
      else if (normSim >= 0.55) reasons.push('Similar to what you usually enjoy');
    }

    // ---- IMPLICIT INTEREST: viewed categories ----
    let viewedCatScore = 0;
    for (const cat of categories) {
      const views = signals.viewedCategories.get(cat) ?? 0;
      if (views > 0) {
        viewedCatScore += Math.log2(views + 1);
      }
    }
    if (viewedCatScore > 0) {
      const maxViewCat = categories.length * Math.log2(20);
      const normViewCat = Math.min(viewedCatScore / Math.max(maxViewCat, 1), 1);
      score += W.VIEWED_CATEGORY * normViewCat;
      reasons.push('Similar to offers you\'ve been browsing');
    }

    // ---- IMPLICIT INTEREST: viewed restaurant ----
    const restaurantViews = signals.viewedRestaurants.get(restaurantId) ?? 0;
    if (restaurantViews > 0) {
      const viewRestNorm = Math.min(restaurantViews / 5, 1);
      score += W.VIEWED_RESTAURANT * viewRestNorm;
      reasons.push('From a restaurant you checked out');
    }

    // ---- PRICE SENSITIVITY ----
    if (signals.avgOrderPrice != null) {
      const offerPrice = (offer.discountedPrice as number) ?? 0;
      if (offerPrice > 0) {
        // Score higher when offer price is close to client's avg spending
        const diff = Math.abs(offerPrice - signals.avgOrderPrice);
        const range = Math.max(signals.avgOrderPrice * 0.5, 1);
        const priceScore = Math.max(0, 1 - diff / range);
        score += W.PRICE_MATCH * priceScore;
        if (priceScore >= 0.7) reasons.push('In your usual price range');
      }
    }

    // ---- CUISINE PREFERENCE MATCH ----
    const prefMatches = categories.filter((c) =>
      signals.cuisinePreferences.includes(c),
    );
    if (prefMatches.length > 0) {
      const prefScore = Math.min(prefMatches.length / Math.max(signals.cuisinePreferences.length, 1), 1);
      score += W.CUISINE_PREF_MATCH * prefScore;
      reasons.push(`Matches your preferences: ${prefMatches.join(', ')}`);
    }

    // ---- ORDER HISTORY CATEGORY MATCH ----
    let historyCatScore = 0;
    for (const cat of categories) {
      const count = signals.orderedCategories.get(cat) ?? 0;
      if (count > 0) {
        historyCatScore += Math.log2(count + 1);
      }
    }
    if (historyCatScore > 0) {
      const maxPossible = Math.log2(11); // log2(10+1) — single well-ordered category ceiling
      const normHistoryScore = Math.min(historyCatScore / Math.max(maxPossible, 1), 1);
      score += W.HISTORY_CAT_MATCH * normHistoryScore;
      reasons.push('Similar to your past orders');
    }

    // ---- RESTAURANT REPEAT ----
    const restaurantOrderCount = signals.orderedRestaurants.get(restaurantId) ?? 0;
    if (restaurantOrderCount > 0) {
      const repeatNorm = Math.min(restaurantOrderCount / 5, 1);
      score += W.RESTAURANT_REPEAT * repeatNorm;
      reasons.push('You\'ve ordered from this restaurant before');
    }

    // ---- PROXIMITY ----
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
      if (distKm <= 5) reasons.push('Nearby restaurant');
    }

    // ---- RATING ----
    const avgRating = (restaurantProfile?.avgRating as number) ?? 0;
    if (avgRating > 0) {
      const ratingNorm = avgRating / 5;
      score += W.RATING * ratingNorm;
      if (avgRating >= 4) reasons.push('Highly rated');
    }

    // ---- DISCOUNT ----
    const original = (offer.originalPrice as number) ?? 0;
    const discounted = (offer.discountedPrice as number) ?? 0;
    if (original > 0) {
      const discountPct = (original - discounted) / original;
      score += W.DISCOUNT * discountPct;
      if (discountPct >= 0.4) reasons.push('Great deal');
    }

    // ---- EXPLORATION (discovery bonus) ----
    const neverOrdered = !signals.orderedRestaurants.has(restaurantId);
    const neverViewed = !signals.viewedRestaurants.has(restaurantId);
    if (neverOrdered && neverViewed) {
      score += W.EXPLORATION;
      reasons.push('New restaurant to discover');
    }

    return { offer, score: Math.round(score * 10000) / 10000, reasons };
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
