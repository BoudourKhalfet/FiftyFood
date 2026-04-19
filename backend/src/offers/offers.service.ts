import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { Category, OfferVisibility } from '@prisma/client';

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY || '';
const AUTHENTICITY_PROMPT = `You are a photo authenticity detector with HIGH SENSITIVITY. Determine if a food photo was genuinely taken today by the seller using their phone, or downloaded from the internet.

REJECT: Stock photo lighting, watermarks, overly perfect styling, studio backgrounds, professional DSLR quality, food blog images.
ACCEPT: Natural phone camera quality, real kitchen/restaurant environment, casual framing, slightly imperfect lighting.

Be STRICT. When in doubt, mark as NOT authentic.`;

const FRESHNESS_PROMPT = `You are an expert food safety inspector with HIGH SENSITIVITY. Examine this food photo for ANY signs of spoilage.

Check for: mold, discoloration, slimy textures, dried-out edges, wilting, unusual colors, separation, curdling.

Rate: fresh (just prepared) | acceptable (minor age signs, safe) | questionable (borderline) | spoiled (unsafe).
Be VERY STRICT. Consumer safety is top priority.`;

const DESCRIPTION_PROMPT_EN = `You are a professional food photographer and marketing copywriter for restaurants. 
Analyze this food photo and generate a SHORT, COMMERCIAL, ENTICING product description suitable for a food surplus/discount app (like FiftyFood).

Requirements:
- Maximum 150 characters
- Highlight food quality, freshness, and appeal
- Include main ingredients or food type
- Make it IRRESISTIBLE to hungry customers
- Professional tone, not casual
- No marketing hype, be authentic
- Example: "Fresh homemade lasagna with layers of creamy ricotta and rich Bolognese sauce. Perfect for dinner!"

Return ONLY the description text, nothing else.`;

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
export class OffersService {
  constructor(private readonly prisma: PrismaService) {}

  private async expirePastOffers() {
    await this.prisma.offer.updateMany({
      where: {
        status: { in: ['ACTIVE', 'PAUSED'] },
        pickupDateTime: { lt: new Date() },
      },
      data: { status: 'EXPIRED' },
    });
  }

  // --- Properly type toolDef as object
  private async callModel<T extends object>(
    model: string,
    systemPrompt: string,
    imageBase64: string,
    toolDef: { function: { name: string } } & Record<string, unknown>,
  ): Promise<T> {
    if (!OPENROUTER_API_KEY) {
      throw new Error('OPENROUTER_API_KEY not configured');
    }

    const imageUrl = imageBase64.startsWith('data:')
      ? imageBase64
      : `data:image/jpeg;base64,${imageBase64}`;

    const imageContent = [
      { type: 'text', text: 'Analyze this food photo.' },
      { type: 'image_url', image_url: { url: imageUrl } },
    ];

    try {
      const response = await fetch(
        'https://openrouter.ai/api/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: imageContent },
            ],
            tools: [toolDef],
            tool_choice: {
              type: 'function',
              function: { name: toolDef.function.name },
            },
          }),
        },
      );

      if (!response.ok) {
        const status = response.status;
        if (status === 429 || status === 402) {
          const errorMsg =
            status === 429 ? 'Rate limit exceeded' : 'API credits exhausted';
          const err: Error & { status?: number } = new Error(errorMsg);
          err.status = status;
          throw err;
        }
        const text = await response.text();
        console.error(`Model ${model} error:`, status, text);
        throw new Error(`Model ${model} failed`);
      }

      // --- Structure the expected response for type safety
      const data = (await response.json()) as {
        choices: {
          message: { tool_calls: { function: { arguments: string } }[] };
        }[];
      };
      const toolCall = data.choices?.[0]?.message?.tool_calls?.[0];
      if (!toolCall) throw new Error(`No tool response from ${model}`);
      return JSON.parse(toolCall.function.arguments) as T;
    } catch (e: unknown) {
      // (e as Error) is best for catching real errors
      console.error(`callModel error for ${model}:`, e);
      throw e;
    }
  }

  // Verifies a food photo using parallel Gemini (authenticity) + GPT checks via OpenRouter.
  async verifyPhoto(imageBase64: string) {
    if (!OPENROUTER_API_KEY) {
      console.error('OPENROUTER_API_KEY is not configured');
      return {
        passed: false,
        messages: ['Verification service not configured.'],
        freshness_rating: 'unknown',
        confidence: 0,
      };
    }

    const authenticityTool = {
      type: 'function',
      function: {
        name: 'check_authenticity',
        description: 'Check if the photo is authentic and recently taken',
        parameters: {
          type: 'object',
          properties: {
            is_authentic: { type: 'boolean' },
            is_recent: { type: 'boolean' },
            production_quality: {
              type: 'string',
              enum: ['casual', 'semi-professional', 'professional', 'stock'],
            },
            confidence: { type: 'number' },
            reasons: { type: 'array', items: { type: 'string' } },
          },
          required: [
            'is_authentic',
            'is_recent',
            'production_quality',
            'confidence',
            'reasons',
          ],
          additionalProperties: false,
        },
      },
    };

    const freshnessTool = {
      type: 'function',
      function: {
        name: 'check_freshness',
        description: 'Assess food quality, freshness and safety',
        parameters: {
          type: 'object',
          properties: {
            food_looks_fresh: { type: 'boolean' },
            freshness_rating: {
              type: 'string',
              enum: ['fresh', 'acceptable', 'questionable', 'spoiled'],
            },
            spoilage_signs: { type: 'array', items: { type: 'string' } },
            confidence: { type: 'number' },
            reasons: { type: 'array', items: { type: 'string' } },
          },
          required: [
            'food_looks_fresh',
            'freshness_rating',
            'spoilage_signs',
            'confidence',
            'reasons',
          ],
          additionalProperties: false,
        },
      },
    };

    try {
      // Run both LLM checks in parallel via OpenRouter (fully typed!)
      const [authResult, freshResult]: [AuthenticityResult, FreshnessResult] =
        await Promise.all([
          this.callModel<AuthenticityResult>(
            'google/gemini-2.5-flash',
            AUTHENTICITY_PROMPT,
            imageBase64,
            authenticityTool,
          ),
          this.callModel<FreshnessResult>(
            'openai/gpt-4-turbo',
            FRESHNESS_PROMPT,
            imageBase64,
            freshnessTool,
          ),
        ]);

      // Aggregate messages
      const messages: string[] = [];
      if (authResult.is_authentic && authResult.is_recent) {
        messages.push(
          '✓ Photo appears authentic and recently taken (Gemini Flash)',
        );
      } else {
        if (!authResult.is_authentic)
          messages.push('✗ Photo may be from internet or stock source');
        if (!authResult.is_recent)
          messages.push('✗ Photo does not appear to be taken today');
        authResult.reasons?.forEach((r: string) => messages.push(`  → ${r}`));
      }

      if (freshResult.food_looks_fresh) {
        messages.push(
          `✓ Food freshness: ${freshResult.freshness_rating} (GPT-4 Turbo)`,
        );
      } else {
        messages.push(
          `✗ Food freshness concern: ${freshResult.freshness_rating} (GPT-4 Turbo)`,
        );
        freshResult.spoilage_signs?.forEach((s: string) =>
          messages.push(`  ⚠ ${s}`),
        );
      }
      freshResult.reasons?.forEach((r: string) => messages.push(`  → ${r}`));

      // Final decision
      const passed =
        authResult.is_authentic &&
        authResult.is_recent &&
        authResult.production_quality !== 'stock' &&
        authResult.production_quality !== 'professional' &&
        freshResult.food_looks_fresh &&
        (freshResult.freshness_rating === 'fresh' ||
          freshResult.freshness_rating === 'acceptable');

      const avgConfidence = Math.round(
        ((authResult.confidence ?? 0) + (freshResult.confidence ?? 0)) / 2,
      );

      // Debug log: print full AI response and decision
      console.log('AI Verification Debug:', {
        authResult,
        freshResult,
        passed,
        messages,
        confidence: avgConfidence,
      });

      return {
        passed,
        is_authentic: authResult.is_authentic,
        is_recent: authResult.is_recent,
        food_looks_fresh: freshResult.food_looks_fresh,
        freshness_rating: freshResult.freshness_rating,
        confidence: avgConfidence,
        messages,
        models_used: {
          authenticity: 'gemini-2.5-flash',
          freshness: 'gpt-4-turbo',
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
    if (!OPENROUTER_API_KEY) {
      throw new Error('OPENROUTER_API_KEY not configured');
    }

    try {
      const response = await fetch(imageUrl);
      if (!response.ok) {
        throw new Error(`Failed to fetch image from URL: ${imageUrl}`);
      }

      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');
      const imageBase64 = `data:image/jpeg;base64,${base64}`;

      const prompt = this.getDescriptionPrompt(language);
      const imageContent = [
        { type: 'text', text: prompt },
        { type: 'image_url', image_url: { url: imageBase64 } },
      ];

      const apiResponse = await fetch(
        'https://openrouter.ai/api/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          },
          body: JSON.stringify({
            model: 'google/gemini-2.5-flash',
            messages: [{ role: 'user', content: imageContent }],
            max_tokens: 200,
            temperature: 0.7,
          }),
        },
      );

      if (!apiResponse.ok) {
        const status = apiResponse.status;
        const errorText = await apiResponse.text();
        console.error(
          `Gemini API error (${status}):`,
          errorText.substring(0, 200),
        );

        if (status === 429 || status === 402) {
          throw new Error(
            status === 429 ? 'Rate limit exceeded' : 'API credits exhausted',
          );
        }
        throw new Error('Failed to generate description');
      }

      const data = (await apiResponse.json()) as {
        choices: { message: { content: string } }[];
      };
      const description = data.choices?.[0]?.message?.content?.trim();

      if (!description) {
        throw new Error('No description generated');
      }

      return {
        description,
        generated_at: new Date().toISOString(),
        model: 'google/gemini-2.5-flash',
      };
    } catch (e: unknown) {
      const err = e as Error & { status?: number };
      console.error('Description generation error:', err);
      throw new BadRequestException(
        err.message || 'Failed to generate description. Please try again.',
      );
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

    return this.prisma.offer.create({
      data: {
        restaurantId: userId,
        photoUrl: dto.photoUrl,
        description: dto.description,
        originalPrice: dto.originalPrice,
        discountedPrice: dto.discountedPrice,
        quantity: dto.quantity,
        pickupTime: dto.pickupTime,
        pickupDateTime: new Date(dto.pickupDateTime),
        categories: normalizedCategories as Category[],
        visibility:
          (dto.visibility as OfferVisibility) || OfferVisibility.IDENTIFIED,
        deliveryAvailable: dto.deliveryAvailable ?? false,
      },
    });
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

    const now = new Date();
    return this.prisma.offer.findMany({
      where: {
        status: 'ACTIVE',
        quantity: { gt: 0 },
        pickupDateTime: { gte: now },
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
              },
            },
          },
        },
      },
    });
  }
}
