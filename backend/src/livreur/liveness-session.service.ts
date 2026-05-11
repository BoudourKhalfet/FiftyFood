import { Injectable, Logger } from '@nestjs/common';
import { randomBytes } from 'crypto';

/**
 * Server-side liveness session management.
 * Stores issued challenges, nonces, expiration, and prevents replay attacks.
 */

interface LivenessSession {
  sessionId: string;
  nonce: string;
  userId: string;
  challenges: string[];
  createdAt: number; // ms
  expiresAt: number; // ms
  used: boolean;
  attempts: number;
}

@Injectable()
export class LivenessSessionService {
  private readonly logger = new Logger(LivenessSessionService.name);

  // In-memory session store (for production, use Redis)
  private sessions = new Map<string, LivenessSession>();

  // WARNING: Both sessions and replayCache are in-memory only.
  // A server restart or horizontal scaling will clear all sessions,
  // allowing replay attacks within the TTL window.
  // Replace with Redis before production deployment.
  private replayCache = new Set<string>();

  // Config
  private readonly SESSION_TTL_MS = 60000; // 60 seconds
  private readonly MAX_ATTEMPTS = 3;
  private readonly CLEANUP_INTERVAL_MS = 120000; // 2 minutes

  constructor() {
    // Periodic cleanup of expired sessions
    setInterval(() => this.cleanup(), this.CLEANUP_INTERVAL_MS);
  }

  /**
   * Issue a new liveness session with randomized challenges.
   * Returns session metadata for the client.
   */
  issueSession(userId: string): {
    sessionId: string;
    nonce: string;
    challenges: string[];
    expiresAt: number;
  } {
    const sessionId = randomBytes(16).toString('hex');
    const nonce = randomBytes(12).toString('hex');
    const challenges = this.generateChallengeSequence();
    const now = Date.now();

    const session: LivenessSession = {
      sessionId,
      nonce,
      userId,
      challenges,
      createdAt: now,
      expiresAt: now + this.SESSION_TTL_MS,
      used: false,
      attempts: 0,
    };

    this.sessions.set(sessionId, session);
    this.logger.log(`[Session] Issued ${sessionId} for user ${userId} challenges=${JSON.stringify(challenges)}`);

    return {
      sessionId,
      nonce,
      challenges,
      expiresAt: session.expiresAt,
    };
  }

  /**
   * Validate and consume a liveness session.
   * Returns the session if valid, throws descriptive error otherwise.
   */
  validateSession(
    sessionId: string,
    nonce: string,
    userId: string,
  ): { valid: boolean; session?: LivenessSession; error?: string } {
    const session = this.sessions.get(sessionId);

    if (!session) {
      this.logger.warn(`[Session] Unknown session: ${sessionId}`);
      return { valid: false, error: 'Invalid session' };
    }

    if (session.userId !== userId) {
      this.logger.warn(`[Session] User mismatch: expected ${session.userId}, got ${userId}`);
      return { valid: false, error: 'Session user mismatch' };
    }

    if (session.nonce !== nonce) {
      this.logger.warn(`[Session] Nonce mismatch for ${sessionId}`);
      return { valid: false, error: 'Invalid nonce' };
    }

    if (session.used) {
      this.logger.warn(`[Session] Already used: ${sessionId}`);
      return { valid: false, error: 'Session already consumed' };
    }

    if (Date.now() > session.expiresAt) {
      this.logger.warn(`[Session] Expired: ${sessionId}`);
      this.sessions.delete(sessionId);
      return { valid: false, error: 'Session expired' };
    }

    session.attempts++;
    if (session.attempts > this.MAX_ATTEMPTS) {
      this.logger.warn(`[Session] Max attempts exceeded: ${sessionId}`);
      this.sessions.delete(sessionId);
      return { valid: false, error: 'Too many attempts' };
    }

    return { valid: true, session };
  }

  /**
   * Mark session as consumed (one-time use).
   */
  consumeSession(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.used = true;
      this.logger.log(`[Session] Consumed: ${sessionId}`);
      // Keep for replay detection, will be cleaned up after TTL
    }
  }

  /**
   * Check if a payload hash has been seen before (replay detection).
   */
  isReplay(payloadHash: string): boolean {
    if (this.replayCache.has(payloadHash)) {
      this.logger.warn(`[Replay] Duplicate payload detected: ${payloadHash}`);
      return true;
    }
    return false;
  }

  /**
   * Register a payload hash in the replay cache.
   */
  registerPayload(payloadHash: string): void {
    this.replayCache.add(payloadHash);
    // Auto-expire after 5 minutes
    setTimeout(() => this.replayCache.delete(payloadHash), 300000);
  }

  /**
   * Check if a session was successfully consumed (liveness passed) for a given user.
   */
  isSessionConsumed(sessionId: string, userId: string): boolean {
    const session = this.sessions.get(sessionId);
    if (!session) return false;
    return session.used && session.userId === userId;
  }

  /**
   * Get the challenges for a session (server-authoritative).
   */
  getSessionChallenges(sessionId: string): string[] | null {
    return this.sessions.get(sessionId)?.challenges ?? null;
  }

  /**
   * Generate a randomized 2-step challenge sequence (no duplicates).
   */
  private generateChallengeSequence(): string[] {
    const all = ['blink', 'turn_left', 'turn_right'];
    const first = all[Math.floor(Math.random() * all.length)];
    const remaining = all.filter(c => c !== first);
    const second = remaining[Math.floor(Math.random() * remaining.length)];
    return [first, second];
  }

  /**
   * Cleanup expired sessions and old replay entries.
   */
  private cleanup(): void {
    const now = Date.now();
    let cleaned = 0;
    for (const [id, session] of this.sessions) {
      // Remove sessions expired more than 2 minutes ago
      if (now > session.expiresAt + 120000) {
        this.sessions.delete(id);
        cleaned++;
      }
    }
    if (cleaned > 0) {
      this.logger.debug(`[Session] Cleaned ${cleaned} expired sessions`);
    }
  }
}
