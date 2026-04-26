import { Injectable, Logger } from '@nestjs/common';
import { AppNotification } from '@prisma/client';
import * as admin from 'firebase-admin';

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private initialized = false;
  private enabled = false;

  constructor() {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      this.enabled = false;
      this.logger.log(
        'FCM disabled: missing Firebase service account environment variables',
      );
      return;
    }

    try {
      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
      }

      this.initialized = true;
      this.enabled = true;
      this.logger.log('FCM initialized');
    } catch (error) {
      this.enabled = false;
      this.logger.error(
        'Failed to initialize Firebase Admin SDK',
        error as Error,
      );
    }
  }

  isEnabled() {
    return this.enabled && this.initialized;
  }

  async sendToTokens(tokens: string[], notification: AppNotification) {
    if (!this.isEnabled() || !tokens.length) {
      return;
    }

    const batches: string[][] = [];
    for (let i = 0; i < tokens.length; i += 500) {
      batches.push(tokens.slice(i, i + 500));
    }

    for (const batch of batches) {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: {
          title: notification.title,
          body: notification.message,
        },
        data: {
          notificationId: notification.id,
          type: notification.type,
          orderId: notification.orderId ?? '',
        },
      });

      if (response.failureCount > 0) {
        this.logger.warn(
          `FCM send finished with ${response.failureCount} failures out of ${batch.length}`,
        );
      }
    }
  }
}
