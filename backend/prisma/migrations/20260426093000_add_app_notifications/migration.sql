-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM (
  'ORDER_STATUS_UPDATED',
  'PICKUP_REMINDER',
  'DELIVERY_CONFIRMATION_REMINDER',
  'REVIEW_RESTAURANT_REMINDER',
  'REVIEW_DELIVERER_REMINDER',
  'NEW_DELIVERY_AVAILABLE',
  'ORDER_READY_FOR_DELIVERER',
  'DELIVERER_PICKUP_TIME_REMINDER'
);

-- AlterTable
ALTER TABLE "Order"
  ADD COLUMN "pickupReminderSentAt" TIMESTAMP(3),
  ADD COLUMN "delivererPickupReminderSentAt" TIMESTAMP(3),
  ADD COLUMN "deliveryConfirmReminderSentAt" TIMESTAMP(3),
  ADD COLUMN "reviewReminderSentAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "AppNotification" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "orderId" TEXT,
  "type" "NotificationType" NOT NULL,
  "title" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "payload" JSONB,
  "isRead" BOOLEAN NOT NULL DEFAULT false,
  "readAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "AppNotification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AppNotification_userId_createdAt_idx" ON "AppNotification"("userId", "createdAt");
CREATE INDEX "AppNotification_userId_isRead_createdAt_idx" ON "AppNotification"("userId", "isRead", "createdAt");
CREATE INDEX "AppNotification_orderId_idx" ON "AppNotification"("orderId");

-- AddForeignKey
ALTER TABLE "AppNotification"
  ADD CONSTRAINT "AppNotification_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AppNotification"
  ADD CONSTRAINT "AppNotification_orderId_fkey"
  FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE SET NULL ON UPDATE CASCADE;
