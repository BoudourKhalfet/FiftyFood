import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmbeddingService } from '../recommendations/embedding.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';
import { Category, OfferVisibility } from '@prisma/client';

// API Keys for different AI services - read lazily to ensure dotenv is loaded
const getGeminiDescriptionKey = () => {
  const key = process.env.GEMINI_API_KEY || '';
  console.log('DEBUG GEMINI_API_KEY:', key ? 'Found (first 10 chars: ' + key.substring(0, 10) + '...)' : 'NOT FOUND');
  return key;
};
const getGeminiVerificationKey = () => {
  const key = process.env.GEMINI_VERIFICATION_KEY || process.env.GEMINI_API_KEY || '';
  console.log('DEBUG GEMINI_VERIFICATION_KEY:', key ? 'Found (first 10 chars: ' + key.substring(0, 10) + '...)' : 'NOT FOUND');
  return key;
};

const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

// Updated prompts - less strict for food verification
const VERIFICATION_PROMPT = `You are a food quality inspector for a restaurant surplus food app.
Analyze this image carefully and respond ONLY with a valid JSON object (no markdown, no code blocks, just raw JSON).

Evaluate:
1. isFood: Is there food visible in this image? (true/false)
2. isGoodQuality: Is the photo visually clear enough to see the food? (true/false - be lenient, even phone photos are fine)
3. isConsumable: Does the food look consumable/edible? Look for obvious signs it's NOT good: mold, rot, visible pests, extreme contamination, trash mixed with food, food thrown in garbage bin. Be reasonably lenient - slightly imperfect food is fine. Only reject if there are clear signs the food is truly not consumable.
4. overallApproved: Should this image be approved for a food surplus sale? (true if it's food and looks reasonably consumable)
5. rejectionReason: If not approved, a short user-friendly reason (null if approved)
6. confidenceScore: Your confidence in the assessment 0-100

Respond ONLY with this JSON:
{
  "isFood": boolean,
  "isGoodQuality": boolean,
  "isConsumable": boolean,
  "overallApproved": boolean,
  "rejectionReason": string | null,
  "confidenceScore": number
}`;

const DESCRIPTION_PROMPT_EN = `You are an expert food marketing copywriter for a restaurant surplus food app called FiftyFood.
Analyze this food image and create an enticing commercial description to help sell this surplus food.
Respond ONLY with a valid JSON object (no markdown, no code blocks, just raw JSON).

Create:
1. title: A short, appetizing name for the dish (max 50 chars)
2. description: A compelling commercial description highlighting taste, ingredients, and occasion (2-3 sentences, max 200 chars)
3. highlights: Array of 3-4 short selling points (e.g. "Freshly prepared", "Generous portion", "Chef's special") - each max 30 chars
4. suggestedPrice: A suggested discount price range like "$8-12" based on what you see (estimate based on dish type)

Write in an enticing, positive, appetizing tone. Make customers want to buy it!

Respond ONLY with:
{
  "title": string,
  "description": string,
  "highlights": string[],
  "suggestedPrice": string
}`;

const DESCRIPTION_PROMPT_FR = `Vous êtes un photographe culinaire professionnel et rédacteur marketing pour les restaurants.
Analysez cette photo de nourriture et générez une description produit COURTE, COMMERCIALE et ALLÉCHANTE adaptée à une application de nourriture excédentaire/discount (comme FiftyFood).

Exigences:
- Maximum 150 caractères
- Mettez en évidence la qualité, la fraîcheur et l'attrait des aliments
- Inclure le type d'ingrédients principaux ou de nourriture
- Rendez-le IRRÉSISTIBLE pour les clients affamés
- Ton professionnel, pas décontracté
- Pas de battage publicitaire, soyez authentique
- Exemple : "Lasagnes maison fraîches avec des couches de ricotta crémeuse et une riche sauce Bolognese. Parfait pour le dîner!"

Retournez UNIQUEMENT le texte de la description, rien d'autre.`;

const DESCRIPTION_PROMPT_AR = `أنت مصور طعام احترافي وكاتب تسويق لمطاعم.
حلل هذه الصورة الغذائية وقم بإنشاء وصف منتج قصير وتجاري وجذاب مناسب لتطبيق الطعام الفائض/الخصم (مثل FiftyFood).

المتطلبات:
- بحد أقصى 150 حرف
- ركز على جودة الطعام والنضارة والجاذبية
- قم بتضمين نوع المكونات الرئيسية أو الطعام
- اجعله لا يقاوم للعملاء الجائعين
- نبرة احترافية وليست عادية
- لا للمبالغة في الإعلان، كن أصليًا
- مثال: "لازانيا منزلية طازجة مع طبقات من الريكوتا الكريمية وصلصة بولونيز الغنية. مثالي للعشاء!"

أرجع النص الوصف فقط، لا شيء آخر.`;

// --- Add interfaces here ---
interface AuthenticityResult {
  is_authentic: boolean;
  is_recent: boolean;
  production_quality?: string;
  confidence?: number;
  reasons?: string[];
}
interface FreshnessResult {
  food_looks_fresh: boolean;
  freshness_rating: string;
  spoilage_signs?: string[];
  confidence?: number;
  reasons?: string[];
}

@Injectable()
export class OffersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OffersService.name);
  private expirationTimer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly embedding: EmbeddingService,
  ) {}

  async onModuleInit() {
    await this.expirePastOffers();
    this.expirationTimer = setInterval(() => {
      void this.expirePastOffers().catch((error: unknown) => {
        this.logger.error('Failed to expire offers', error as Error);
      });
    }, 60_000);
  }

  onModuleDestroy() {
    if (this.expirationTimer) {
      clearInterval(this.expirationTimer);
      this.expirationTimer = undefined;
    }
  }

  private parsePickupTimeRange(pickupTime: string | null): {
    startHour: number;
    startMinute: number;
    endHour: number;
    endMinute: number;
  } | null {
    const source = (pickupTime ?? '').trim();
    const matches = [...source.matchAll(/(\d{1,2}):(\d{2})/g)];
    if (matches.length < 2) return null;

    return {
      startHour: Number(matches[0][1]),
      startMinute: Number(matches[0][2]),
      endHour: Number(matches[matches.length - 1][1]),
      endMinute: Number(matches[matches.length - 1][2]),
    };
  }

  private normalizePickupDateTime(
    pickupDateTime: Date,
    pickupTime: string | null,
  ): Date {
    const range = this.parsePickupTimeRange(pickupTime);
    if (!range) return pickupDateTime;

    const normalized = new Date(pickupDateTime);
    const startMinutes = range.startHour * 60 + range.startMinute;
    const endMinutes = range.endHour * 60 + range.endMinute;
    const crossesMidnight = endMinutes <= startMinutes;

    if (crossesMidnight) {
      normalized.setDate(normalized.getDate() + 1);
    }
    normalized.setHours(range.endHour, range.endMinute, 0, 0);
    return normalized;
  }

  private normalizePickupDateTimeFromNow(pickupTime: string | null): Date {
    return this.normalizePickupDateTime(new Date(), pickupTime);
  }

  private validatePickupTimeWindow(pickupTime: string | null) {
    const range = this.parsePickupTimeRange(pickupTime);
    if (!range) {
      throw new BadRequestException(
        'Invalid pickup time format. Expected HH:mm - HH:mm.',
      );
    }

    if (
      range.startHour === range.endHour &&
      range.startMinute === range.endMinute
    ) {
      throw new BadRequestException(
        'Pickup start time must be different from end time.',
      );
    }

    const now = new Date();
    let start = new Date(now);
    start.setHours(range.startHour, range.startMinute, 0, 0);

    let end = new Date(now);
    end.setHours(range.endHour, range.endMinute, 0, 0);

    if (end.getTime() <= start.getTime()) {
      end = new Date(end.getTime() + 24 * 60 * 60 * 1000);
    }

    // Keep validation strict by requiring the next full window to be in the future.
    if (start.getTime() <= now.getTime()) {
      start = new Date(start.getTime() + 24 * 60 * 60 * 1000);
      end = new Date(end.getTime() + 24 * 60 * 60 * 1000);
    }

    if (start.getTime() <= now.getTime() || end.getTime() <= now.getTime()) {
      throw new BadRequestException(
        'Pickup start and end times must be after now.',
      );
    }
  }

  private async expirePastOffers() {
    const candidates = await this.prisma.offer.findMany({
      where: {
        status: { in: ['ACTIVE', 'PAUSED'] },
        pickupDateTime: { lt: new Date() },
      },
      select: {
        id: true,
        pickupDateTime: true,
      },
    });

    const nowMs = Date.now();
    const expiredIds = candidates
      .filter((offer) => offer.pickupDateTime.getTime() <= nowMs)
      .map((offer) => offer.id);

    if (!expiredIds.length) return;

    await this.prisma.offer.updateMany({
      where: { id: { in: expiredIds } },
      data: { status: 'EXPIRED' },
    });
  }

  // --- Gemini API helper for image analysis
  private async callGemini<T extends object>(
    apiKey: string,
    prompt: string,
    imageBase64: string,
    mimeType: string = 'image/jpeg',
  ): Promise<T> {
    const payload = {
      contents: [
        {
          parts: [
            {
              inlineData: {
                mimeType: mimeType,
                data: imageBase64,
              },
            },
            { text: prompt },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 1024,
      },
    };

    const response = await fetch(`${GEMINI_API_BASE}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const err = await response.json();
      throw new Error(err?.error?.message || `Gemini API error: ${response.status}`);
    }

    const data = (await response.json()) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };

    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) throw new Error('No response from Gemini');

    // Strip markdown code blocks if present and parse JSON
    const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]) as T;
    }
    throw new Error('Failed to parse JSON from Gemini response');
  }

  // Verifies a food photo using Gemini API with separate verification key.
  async verifyPhoto(imageBase64: string, mimeType: string = 'image/jpeg') {
    const verificationKey = getGeminiVerificationKey();
    if (!verificationKey) {
      console.error('GEMINI_VERIFICATION_KEY is not configured');
      return {
        passed: false,
        messages: ['Verification service not configured.'],
        freshness_rating: 'unknown',
        confidence: 0,
      };
    }

    // Type for verification result
    type VerificationResult = {
      isFood: boolean;
      isGoodQuality: boolean;
      isConsumable: boolean;
      overallApproved: boolean;
      rejectionReason: string | null;
      confidenceScore: number;
    };

    try {
      // Call Gemini for food verification
      const result = await this.callGemini<VerificationResult>(
        verificationKey,
        VERIFICATION_PROMPT,
        imageBase64,
        mimeType,
      );

      // Compose messages
      const messages: string[] = [];

      if (result.overallApproved) {
        messages.push('✓ Photo approved: Valid food image');
        if (result.isFood) messages.push('✓ Food detected in image');
        if (result.isGoodQuality) messages.push('✓ Photo quality is acceptable');
        if (result.isConsumable) messages.push('✓ Food appears consumable');
      } else {
        messages.push('✗ Photo verification failed');
        if (!result.isFood) messages.push('✗ No food detected in image');
        if (!result.isGoodQuality) messages.push('✗ Photo quality too low');
        if (!result.isConsumable) messages.push('✗ Food does not appear consumable');
        if (result.rejectionReason) messages.push(`→ ${result.rejectionReason}`);
      }

      // Debug log
      console.log('AI Verification Debug:', {
        result,
        passed: result.overallApproved,
        messages,
        confidence: result.confidenceScore,
      });

      return {
        passed: result.overallApproved,
        is_authentic: result.isFood && result.isConsumable,
        is_recent: true, // Gemini doesn't check this, assume true
        food_looks_fresh: result.isConsumable,
        freshness_rating: result.isConsumable ? 'acceptable' : 'spoiled',
        confidence: result.confidenceScore,
        messages,
        models_used: {
          verification: 'gemini-2.0-flash',
        },
      };
    } catch (e: unknown) {
      const err = e as Error & { status?: number };
      console.error('Photo verification error:', err);
      if (err.status === 429 || err.status === 402) {
        return {
          passed: false,
          messages: [
            err.message || 'Verification service temporarily unavailable.',
          ],
          freshness_rating: 'unknown',
          confidence: 0,
        };
      }
      return {
        passed: false,
        messages: ['Verification failed. Please try again.'],
        freshness_rating: 'unknown',
        confidence: 0,
      };
    }
  }

  // Generate a commercial description for a food photo using Gemini
  private getDescriptionPrompt(language: string = 'en'): string {
    switch (language) {
      case 'fr':
        return DESCRIPTION_PROMPT_FR;
      case 'ar':
        return DESCRIPTION_PROMPT_AR;
      default:
        return DESCRIPTION_PROMPT_EN;
    }
  }

  async generateDescription(imageUrl: string, language: string = 'en') {
    // If no API key, return empty so frontend can use manual entry
    const descriptionKey = getGeminiDescriptionKey();
    if (!descriptionKey) {
      console.warn('GEMINI_API_KEY not configured - using manual mode');
      return {
        description: '',
        generated_at: new Date().toISOString(),
        model: 'manual',
        error: 'AI not configured - please enter description manually',
      };
    }

    try {
      const response = await fetch(imageUrl);
      if (!response.ok) {
        throw new Error(`Failed to fetch image from URL: ${imageUrl}`);
      }

      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');

      const prompt = this.getDescriptionPrompt(language);

      // Use Gemini API directly for description generation
      const result = await this.callGemini<{
        title: string;
        description: string;
        highlights: string[];
        suggestedPrice: string;
      }>(descriptionKey, prompt, base64, 'image/jpeg');

      const fullDescription = `${result.title}\n\n${result.description}\n\nHighlights: ${result.highlights.join(', ')}`;

      return {
        description: fullDescription,
        generated_at: new Date().toISOString(),
        model: 'gemini-2.0-flash',
        title: result.title,
        highlights: result.highlights,
        suggestedPrice: result.suggestedPrice,
      };
    } catch (e: unknown) {
      const err = e as Error & { status?: number };
      console.error('Description generation error:', err);
      // Return empty for manual entry instead of throwing
      return {
        description: '',
        generated_at: new Date().toISOString(),
        model: 'manual',
        error: 'AI service error - please enter description manually',
      };
    }
  }

  // Create a new offer for a restaurant.
  async createOffer(userId: string, dto: CreateOfferDto) {
    // Validate discount is between 10-90%
    const discountPct =
      ((dto.originalPrice - dto.discountedPrice) / dto.originalPrice) * 100;
    if (discountPct < 10 || discountPct > 90) {
      throw new ForbiddenException(
        'Discount must be between 10% and 90% of the original price.',
      );
    }

    if (!dto.pickupDateTime) {
      throw new BadRequestException('pickupDateTime is required');
    }

    this.validatePickupTimeWindow(dto.pickupTime);

    const normalizedCategories = dto.categories.map((category) =>
      category
        .trim()
        .toUpperCase()
        .replace(/[-\s]+/g, '_'),
    );
    const invalidCategory = normalizedCategories.find(
      (category) => !Object.values(Category).includes(category as Category),
    );
    if (invalidCategory) {
      throw new BadRequestException(`Invalid category: ${invalidCategory}`);
    }

    const created = await this.prisma.offer.create({
      data: {
        restaurantId: userId,
        photoUrl: dto.photoUrl,
        description: dto.description,
        originalPrice: dto.originalPrice,
        discountedPrice: dto.discountedPrice,
        quantity: dto.quantity,
        pickupTime: dto.pickupTime,
        pickupDateTime: this.normalizePickupDateTime(
          new Date(dto.pickupDateTime),
          dto.pickupTime,
        ),
        categories: normalizedCategories as Category[],
        visibility:
          (dto.visibility as OfferVisibility) || OfferVisibility.IDENTIFIED,
        deliveryAvailable: dto.deliveryAvailable ?? false,
      },
    });

    // Fire-and-forget: generate and store semantic embedding
    void this.embedOffer(created.id, dto.description, normalizedCategories);

    return created;
  }

  private async embedOffer(
    offerId: string,
    description: string,
    categories: string[],
  ): Promise<void> {
    try {
      const text = this.embedding.buildOfferText(description, categories);
      const vector = await this.embedding.embed(text);
      if (!vector) return;
      await this.prisma.offer.update({
        where: { id: offerId },
        data: { descriptionEmbedding: vector },
      });
    } catch (err) {
      this.logger.warn(`Failed to embed offer ${offerId}`, err);
    }
  }

  // List all offers for a restaurant.
  async getMyOffers(userId: string) {
    await this.expirePastOffers();

    return this.prisma.offer.findMany({
      where: { restaurantId: userId, NOT: { status: 'DELETED' } },
      orderBy: { createdAt: 'desc' },
    });
  }

  // Delete an offer (only by the restaurant that owns it).
  async deleteOffer(userId: string, offerId: string) {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.restaurantId !== userId)
      throw new ForbiddenException('Not your offer');

    return this.prisma.offer.update({
      where: { id: offerId },
      data: { status: 'DELETED' },
    });
  }

  // Update editable offer fields (except photo) for the owning restaurant.
  async updateOffer(userId: string, offerId: string, dto: UpdateOfferDto) {
    await this.expirePastOffers();

    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.restaurantId !== userId) {
      throw new ForbiddenException('Not your offer');
    }
    if (offer.status === 'DELETED') {
      throw new BadRequestException('Cannot edit a deleted offer');
    }

    const nextOriginalPrice = dto.originalPrice ?? offer.originalPrice;
    const nextDiscountedPrice = dto.discountedPrice ?? offer.discountedPrice;

    const discountPct =
      ((nextOriginalPrice - nextDiscountedPrice) / nextOriginalPrice) * 100;
    if (discountPct < 10 || discountPct > 90) {
      throw new ForbiddenException(
        'Discount must be between 10% and 90% of the original price.',
      );
    }

    const nextPickupTime = dto.pickupTime ?? offer.pickupTime;
    this.validatePickupTimeWindow(nextPickupTime);

    const nextPickupDateTime =
      offer.status === 'EXPIRED'
        ? this.normalizePickupDateTimeFromNow(nextPickupTime)
        : this.normalizePickupDateTime(offer.pickupDateTime, nextPickupTime);

    // Logic: If offer is SOLD_OUT, quantity is increased, and pickupDateTime is in the future, set status to ACTIVE
    let nextStatus = offer.status;
    const now = new Date();
    const newQuantity = dto.quantity ?? offer.quantity;
    if (
      offer.status === 'SOLD_OUT' &&
      newQuantity > offer.quantity &&
      nextPickupDateTime > now
    ) {
      nextStatus = 'ACTIVE';
    } else if (offer.status === 'EXPIRED') {
      nextStatus = 'ACTIVE';
    }

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: {
        description: dto.description ?? offer.description,
        originalPrice: nextOriginalPrice,
        discountedPrice: nextDiscountedPrice,
        quantity: newQuantity,
        pickupTime: nextPickupTime,
        pickupDateTime: nextPickupDateTime,
        status: nextStatus,
      },
    });

    // Re-embed if description changed
    if (dto.description && dto.description !== offer.description) {
      void this.embedOffer(
        offerId,
        dto.description,
        (updated.categories as string[]),
      );
    }

    return updated;
  }

  // Toggle offer visibility between IDENTIFIED and ANONYMOUS.
  async toggleVisibility(userId: string, offerId: string) {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.restaurantId !== userId)
      throw new ForbiddenException('Not your offer');

    const newVisibility =
      offer.visibility === OfferVisibility.IDENTIFIED
        ? OfferVisibility.ANONYMOUS
        : OfferVisibility.IDENTIFIED;

    return this.prisma.offer.update({
      where: { id: offerId },
      data: { visibility: newVisibility },
    });
  }

  // Toggle offer status between ACTIVE and PAUSED.
  async toggleStatus(userId: string, offerId: string) {
    await this.expirePastOffers();

    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.restaurantId !== userId)
      throw new ForbiddenException('Not your offer');

    if (offer.status !== 'ACTIVE' && offer.status !== 'PAUSED') {
      throw new BadRequestException(
        'Only ACTIVE or PAUSED offers can be toggled',
      );
    }

    const newStatus = offer.status === 'ACTIVE' ? 'PAUSED' : 'ACTIVE';

    return this.prisma.offer.update({
      where: { id: offerId },
      data: { status: newStatus },
    });
  }

  // List all active, visible offers for clients
  async getAvailableOffers() {
    await this.expirePastOffers();

    return this.prisma.offer.findMany({
      where: {
        status: 'ACTIVE',
        quantity: { gt: 0 },
      },
      orderBy: { createdAt: 'desc' },
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
    });
  }

  // Decrement the quantity of an offer
  async decrementQuantity(offerId: string, quantityToDecrement: number) {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });

    if (!offer) {
      throw new NotFoundException('Offer not found');
    }

    const newQuantity = Math.max(0, offer.quantity - quantityToDecrement);

    return this.prisma.offer.update({
      where: { id: offerId },
      data: {
        quantity: newQuantity,
        status: newQuantity === 0 ? 'SOLD_OUT' : offer.status,
      },
    });
  }
}
