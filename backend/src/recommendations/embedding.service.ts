import { Injectable, Logger } from '@nestjs/common';

const HF_API_KEY = process.env.HF_API_KEY || '';
const HF_MODEL = 'sentence-transformers/all-MiniLM-L6-v2';
const HF_URL = `https://router.huggingface.co/hf-inference/models/${HF_MODEL}/pipeline/feature-extraction`;

@Injectable()
export class EmbeddingService {
  private readonly logger = new Logger(EmbeddingService.name);

  // -----------------------------------------------------------------------
  // Generate embedding vector for a text string via HF Inference API
  // Returns null if the API is unavailable or not configured.
  // -----------------------------------------------------------------------

  async embed(text: string): Promise<number[] | null> {
    if (!HF_API_KEY) {
      this.logger.warn('HF_API_KEY not configured — skipping embedding');
      return null;
    }

    try {
      const response = await fetch(HF_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${HF_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ inputs: text }),
      });

      if (!response.ok) {
        this.logger.warn(`HF API returned ${response.status}: ${await response.text()}`);
        return null;
      }

      const data = (await response.json()) as number[] | number[][];

      // The feature-extraction pipeline may return a 2D array (batch) or 1D
      if (Array.isArray(data[0])) {
        return (data as number[][])[0];
      }
      return data as number[];
    } catch (err) {
      this.logger.warn('Failed to call HF embedding API', err);
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Build the text input for an offer (description + categories combined)
  // -----------------------------------------------------------------------

  buildOfferText(description: string, categories: string[]): string {
    const cats = categories.map((c) => c.replace(/_/g, ' ').toLowerCase()).join(', ');
    return `${description} [${cats}]`.trim();
  }

  // -----------------------------------------------------------------------
  // Cosine similarity between two equal-length vectors
  // Returns 0 if either vector is empty or they differ in length.
  // -----------------------------------------------------------------------

  cosineSimilarity(a: number[], b: number[]): number {
    if (!a.length || !b.length || a.length !== b.length) return 0;

    let dot = 0;
    let normA = 0;
    let normB = 0;

    for (let i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    const denom = Math.sqrt(normA) * Math.sqrt(normB);
    return denom === 0 ? 0 : dot / denom;
  }

  // -----------------------------------------------------------------------
  // Average a list of vectors into a single centroid vector (taste profile)
  // Returns null if the list is empty.
  // -----------------------------------------------------------------------

  averageVectors(vectors: number[][]): number[] | null {
    const valid = vectors.filter((v) => v.length > 0);
    if (!valid.length) return null;

    const dim = valid[0].length;
    const avg = new Array<number>(dim).fill(0);

    for (const vec of valid) {
      for (let i = 0; i < dim; i++) {
        avg[i] += vec[i];
      }
    }

    for (let i = 0; i < dim; i++) {
      avg[i] /= valid.length;
    }

    return avg;
  }
}
