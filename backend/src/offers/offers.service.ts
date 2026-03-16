import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { OfferVisibility } from '@prisma/client';

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY || '';
const AUTHENTICITY_PROMPT = `You are a photo authenticity detector with HIGH SENSITIVITY. Determine if a food photo was genuinely taken today by the seller using their phone, or downloaded from the internet.

REJECT: Stock photo lighting, watermarks, overly perfect styling, studio backgrounds, professional DSLR quality, food blog images.
ACCEPT: Natural phone camera quality, real kitchen/restaurant environment, casual framing, slightly imperfect lighting.

Be STRICT. When in doubt, mark as NOT authentic.`;

const FRESHNESS_PROMPT = `You are an expert food safety inspector with HIGH SENSITIVITY. Examine this food photo for ANY signs of spoilage.

Check for: mold, discoloration, slimy textures, dried-out edges, wilting, unusual colors, separation, curdling.

Rate: fresh (just prepared) | acceptable (minor age signs, safe) | questionable (borderline) | spoiled (unsafe).
Be VERY STRICT. Consumer safety is top priority.`;

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

  // --- Properly type toolDef as object
  private async callModel<T extends object>(
    model: string,
    systemPrompt: string,
    imageBase64: string,
    toolDef: object,
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
              function: { name: (toolDef as any).function.name }, // unavoidable due to OpenAI's API shape
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

    return this.prisma.offer.create({
      data: {
        restaurantId: userId,
        photoUrl: dto.photoUrl,
        description: dto.description,
        originalPrice: dto.originalPrice,
        discountedPrice: dto.discountedPrice,
        quantity: dto.quantity,
        pickupTime: dto.pickupTime,
        visibility:
          (dto.visibility as OfferVisibility) || OfferVisibility.IDENTIFIED,
        deliveryAvailable: dto.deliveryAvailable ?? false,
      },
    });
  }

  // List all offers for a restaurant.
  async getMyOffers(userId: string) {
    return this.prisma.offer.findMany({
      where: { restaurantId: userId },
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

    return this.prisma.offer.delete({ where: { id: offerId } });
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
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.restaurantId !== userId)
      throw new ForbiddenException('Not your offer');

    const newStatus = offer.status === 'ACTIVE' ? 'PAUSED' : 'ACTIVE';

    return this.prisma.offer.update({
      where: { id: offerId },
      data: { status: newStatus },
    });
  }

  // List all active, visible offers for clients
  async getAvailableOffers() {
    return this.prisma.offer.findMany({
      where: {
        status: 'ACTIVE',
        quantity: { gt: 0 },
        // Optionally add pickup time/date >= now, etc.
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
