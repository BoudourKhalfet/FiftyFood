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

// API Keys for AI services - read lazily to ensure dotenv is loaded
const getOpenRouterKey = () => {
  const key = process.env.OPENROUTER_API_KEY || '';
  return key;
};
const getOpenRouterVerificationKey = () => {
  const key = process.env.OPENROUTER_VERIFICATION_KEY || process.env.OPENROUTER_API_KEY || '';
  return key;
};

const OPENROUTER_API_BASE = 'https://openrouter.ai/api/v1/chat/completions';
const OPENROUTER_VERIFICATION_MODEL = process.env.OPENROUTER_VERIFICATION_MODEL || 'google/gemini-2.0-flash-lite-001';
const OPENROUTER_DESCRIPTION_MODEL =
  process.env.OPENROUTER_DESCRIPTION_MODEL || 'google/gemini-2.0-flash-lite-001';
const OPENROUTER_DESCRIPTION_FALLBACK_MODELS = [
  'google/gemini-2.0-flash-lite-001',
  'google/gemini-2.0-flash-001',
  'google/gemini-1.5-flash',
];

// Updated prompts - less strict for food verification
const VERIFICATION_PROMPT = `You are a food quality inspector for a restaurant surplus food app.
Analyze this image carefully and respond ONLY with a valid JSON object (no markdown, no code blocks, just raw JSON).

Evaluate:
1. isFood: Is there food visible in this image? (true/false)
2. isGoodQuality: Is the photo visually clear enough to see the food? (true/false - phone photos are fine, but reject if the food itself is blurry or out of focus)
3. isConsumable: Does the food look consumable/edible? Look for obvious signs it's NOT good: mold, rot, visible pests, extreme contamination, trash mixed with food, food thrown in garbage bin. Be reasonably lenient - slightly imperfect food is fine. Only reject if there are clear signs the food is truly not consumable.
4. overallApproved: Should this image be approved for a food surplus sale? (true only if it's food, looks reasonably consumable, AND the plating is clean/presentable). Reject if the plate/bowl is messy, smeared, or looks unappetizing.
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

const DESCRIPTION_PROMPT_EN = `You are a restaurant menu copywriter for a surplus food app called FiftyFood.
Analyze the image and write a strong, menu-style presentation. Use the authentic dish name when you can recognize it (e.g., "Brik tunisien", "Mloukhia tunisienne", "Shakshuka", "Sushi maki"). If you are unsure, use a neutral but accurate name based on what you see and avoid assigning a different country or region. Do NOT claim web research or external sources; rely only on the image.
Respond ONLY with a valid JSON object (no markdown, no code blocks, just raw JSON).

Create:
1. title: The real dish name when possible; otherwise a clear descriptive name (max 60 chars)
2. description: A menu-style description that sounds like a restaurant menu item (3-4 sentences, 320-420 chars). Highlight taste, texture, key ingredients, and a serving suggestion. Use confident, premium wording without exaggeration.
3. highlights: Array of 4-5 short menu-style selling points (max 40 chars each)
4. suggestedPrice: A suggested discount price range like "$8-12" based on what you see (estimate based on dish type)

Respond ONLY with:
{
  "title": string,
  "description"8-12 DT" based on what you see

IMPORTANT: If you see thin vermicelli noodles with chicken and vegetables, call it "Cheveux d'ange" not "Tagine". If you see couscous, specify if it's "Couscous au poisson" or "Couscous viande".
ring
}`;

const DESCRIPTION_PROMPT_FR = `Vous êtes un rédacteur de menus pour restaurants (application FiftyFood).
Analysez la photo et utilisez le NOM AUTHENTIQUE du plat lorsque vous le reconnaissez (ex: "Brik tunisien", "Mloukhia tunisienne", "Couscous royal", "Ramen tonkotsu"). Si vous n'êtes pas sûr, utilisez un nom descriptif clair et évitez d'attribuer une autre région ou pays. Ne prétendez pas faire de recherche web; basez-vous uniquement sur l'image.

Exigences:
- Ton menu de restaurant, appétissant et précis
- 3-4 phrases (320-420 caractères)
- Mettre en avant goûts, textures, ingrédients clés, et suggestion de service
- Pas d'exagération, style premium

Retournez UNIQUEMENT un objet JSON:
{
  "title": string,
  "description": string,
  "highlights": string[],
  "suggestedPrice": string
}`;

const DESCRIPTION_PROMPT_AR = `أنت كاتب قوائم مطاعم لتطبيق FiftyFood.
حلل الصورة واستخدم الاسم الحقيقي للطبق عندما تتعرف عليه (مثال: "بريك تونسي"، "ملوخية تونسية"). إذا لم تكن متأكدا، استخدم اسما وصفيا دقيقا وتجنب نسبته لبلد آخر. لا تدّعي البحث على الويب، اعتمد على الصورة فقط.

المتطلبات:
- أسلوب قائمة مطعم جذاب ودقيق
- 3-4 جمل (320-420 حرف)
- إبراز الطعم والقوام والمكونات الأساسية واقتراح التقديم
- بدون مبالغة، أسلوب راق

أرجع فقط كائن JSON:
{
  "title": string,
  "description": string,
  "highlights": string[],
  "suggestedPrice": string
}`;

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
      normalized.setUTCDate(normalized.getUTCDate() + 1);
    }
    normalized.setUTCHours(range.endHour, range.endMinute, 0, 0);
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
    start.setUTCHours(range.startHour, range.startMinute, 0, 0);

    let end = new Date(now);
    end.setUTCHours(range.endHour, range.endMinute, 0, 0);

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

  // --- OpenRouter API helper for image analysis (OpenAI-compatible)
  private async callOpenRouterRaw(
    apiKey: string,
    model: string,
    prompt: string,
    imageBase64: string,
    mimeType: string = 'image/jpeg',
  ): Promise<string> {
    if (!apiKey) throw new Error('OPENROUTER_API_KEY is not configured');

    const payload = {
      model: model,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image_url',
              image_url: { url: `data:${mimeType};base64,${imageBase64}` },
            },
            { type: 'text', text: prompt },
          ],
        },
      ],
      temperature: 0.4,
      max_tokens: 1024,
    };

    const response = await fetch(OPENROUTER_API_BASE, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://fiftyfood.app',
        'X-Title': 'FiftyFood',
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const err = await response.json();
      throw new Error(err?.error?.message || `OpenRouter API error: ${response.status}`);
    }

    const data = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
    };

    const text = data?.choices?.[0]?.message?.content;
    if (!text) throw new Error('No response from OpenRouter');
    return text;
  }

  private parseJsonFromText<T extends object>(text: string): T | null {
    const cleaned = text
      .replace(/```json\n?/gi, '')
      .replace(/```\n?/g, '')
      .trim();
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;
    try {
      return JSON.parse(jsonMatch[0]) as T;
    } catch {
      return null;
    }
  }

  private buildFallbackTitle(description: string): string {
    const firstLine = description
      .split(/\r?\n/)
      .map((line) => line.trim())
      .find((line) => line.length > 0) || description.trim();
    const firstSentence = firstLine.split(/[.!?]/)[0].trim();
    const base = firstSentence.length > 0 ? firstSentence : firstLine;
    return base.length > 50 ? `${base.slice(0, 47).trim()}...` : base;
  }

  private sanitizeDescriptionText(text: string): string {
    return text
      .replace(/```[\s\S]*?```/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private async callOpenRouter<T extends object>(
    apiKey: string,
    model: string,
    prompt: string,
    imageBase64: string,
    mimeType: string = 'image/jpeg',
  ): Promise<T> {
    const raw = await this.callOpenRouterRaw(
      apiKey,
      model,
      prompt,
      imageBase64,
      mimeType,
    );
    const parsed = this.parseJsonFromText<T>(raw);
    if (!parsed) {
      throw new Error('Failed to parse JSON from OpenRouter response');
    }
    return parsed;
  }

  private stripDataUrlPrefix(imageBase64OrDataUrl: string): {
    base64: string;
    mimeType: string;
  } {
    const trimmed = imageBase64OrDataUrl.trim();
    if (!trimmed.startsWith('data:')) {
      return { base64: trimmed, mimeType: 'image/jpeg' };
    }

    const match = trimmed.match(/^data:([^;]+);base64,(.*)$/i);
    if (!match) {
      return { base64: trimmed, mimeType: 'image/jpeg' };
    }

    return { base64: match[2], mimeType: match[1] };
  }

  private async fetchImageAsBase64(imageUrl: string): Promise<{
    base64: string;
    mimeType: string;
  }> {
    if (imageUrl.startsWith('data:')) {
      return this.stripDataUrlPrefix(imageUrl);
    }

    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch image from URL: ${imageUrl}`);
    }

    const mimeType = response.headers.get('content-type') || 'image/jpeg';
    const buffer = await response.arrayBuffer();
    const base64 = Buffer.from(buffer).toString('base64');
    return { base64, mimeType };
  }

  // Verifies a food photo using OpenRouter API.
  async verifyPhoto(imageBase64: string, mimeType: string = 'image/jpeg') {
    const verificationKey = getOpenRouterVerificationKey();
    if (!verificationKey) {
      this.logger.warn('OPENROUTER_API_KEY is not configured - skipping verification');
      return {
        passed: true,
        skipped: true,
        messages: ['Verification skipped - AI not configured.'],
        freshness_rating: 'unknown',
        confidence: 0,
        is_authentic: true,
        is_recent: true,
        food_looks_fresh: true,
      };
    }

    const cleaned = this.stripDataUrlPrefix(imageBase64);

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
      // Call OpenRouter for food verification
      const result = await this.callOpenRouter<VerificationResult>(
        verificationKey,
        OPENROUTER_VERIFICATION_MODEL,
        VERIFICATION_PROMPT,
        cleaned.base64,
        cleaned.mimeType || mimeType,
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
          verification: OPENROUTER_VERIFICATION_MODEL,
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

  async verifyPhotoFromUrl(imageUrl: string) {
    const { base64, mimeType } = await this.fetchImageAsBase64(imageUrl);
    return this.verifyPhoto(base64, mimeType);
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
    const descriptionKey = getOpenRouterKey();
    if (!descriptionKey) {
      console.warn('OPENROUTER_API_KEY not configured - using manual mode');
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

      // Use OpenRouter API for description generation
      const modelsToTry = [
        OPENROUTER_DESCRIPTION_MODEL,
        ...OPENROUTER_DESCRIPTION_FALLBACK_MODELS,
      ].filter((value, index, self) => self.indexOf(value) === index);

      let lastError: Error | null = null;
      let usedModel = OPENROUTER_DESCRIPTION_MODEL;
      let result:
        | {
            title: string;
            description: string;
            highlights: string[];
            suggestedPrice: string;
          }
        | undefined;

      for (const model of modelsToTry) {
        try {
          usedModel = model;
          const raw = await this.callOpenRouterRaw(
            descriptionKey,
            model,
            prompt,
            base64,
            'image/jpeg',
          );
          const parsed = this.parseJsonFromText<{
            title: string;
            description: string;
            highlights: string[];
            suggestedPrice: string;
          }>(raw);

          if (parsed) {
            result = parsed;
            break;
          }

          const fallbackText = this.sanitizeDescriptionText(raw);
          if (fallbackText.length > 0) {
            result = {
              title: this.buildFallbackTitle(fallbackText),
              description: fallbackText.slice(0, 200),
              highlights: [],
              suggestedPrice: '',
            };
            break;
          }
        } catch (error) {
          const err = error as Error;
          lastError = err;
          if (!err.message.includes('No endpoints found')) {
            throw err;
          }
        }
      }

      if (!result) {
        throw lastError ?? new Error('Description generation failed');
      }

      const highlightText = result.highlights?.length
        ? `\n\nHighlights: ${result.highlights.join(', ')}`
        : '';
      const fullDescription = `${result.title}\n\n${result.description}${highlightText}`;

      return {
        description: fullDescription,
        generated_at: new Date().toISOString(),
        model: usedModel,
        title: result.title,
        highlights: result.highlights ?? [],
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
    if (discountPct < 20 || discountPct > 60) {
      throw new ForbiddenException(
        'Discount must be between 20% and 60% of the original price.',
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

    // Parse pickupDateTime and validate it's in the future
    let pickupDate: Date;
    try {
      pickupDate = new Date(dto.pickupDateTime);
      if (isNaN(pickupDate.getTime())) {
        throw new Error('Invalid date');
      }
    } catch {
      throw new BadRequestException(
        'Invalid pickupDateTime format. Expected ISO 8601 date.',
      );
    }

    const now = new Date();
    if (pickupDate <= now) {
      throw new BadRequestException(
        'pickupDateTime must be in the future.',
      );
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
          pickupDate,
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
    if (discountPct < 20 || discountPct > 60) {
      throw new ForbiddenException(
        'Discount must be between 20% and 60% of the original price.',
      );
    }

    const nextPickupTime = dto.pickupTime ?? offer.pickupTime;
    this.validatePickupTimeWindow(nextPickupTime);

    // Handle pickupDateTime update
    let nextPickupDateTime = offer.pickupDateTime;
    if (dto.pickupDateTime) {
      try {
        const newPickupDate = new Date(dto.pickupDateTime);
        if (isNaN(newPickupDate.getTime())) {
          throw new Error('Invalid date');
        }
        const now = new Date();
        if (newPickupDate <= now) {
          throw new BadRequestException(
            'pickupDateTime must be in the future.',
          );
        }
        nextPickupDateTime = this.normalizePickupDateTime(newPickupDate, nextPickupTime);
      } catch (error) {
        if (error instanceof BadRequestException) {
          throw error;
        }
        throw new BadRequestException(
          'Invalid pickupDateTime format. Expected ISO 8601 date.',
        );
      }
    } else if (offer.status === 'EXPIRED') {
      nextPickupDateTime = this.normalizePickupDateTimeFromNow(nextPickupTime);
    } else {
      nextPickupDateTime = this.normalizePickupDateTime(offer.pickupDateTime, nextPickupTime);
    }

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
    } else if (offer.status === 'EXPIRED' && nextPickupDateTime > now) {
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
