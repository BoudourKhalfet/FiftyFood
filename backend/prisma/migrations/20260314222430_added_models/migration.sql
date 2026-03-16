/*
  Warnings:

  - You are about to drop the `PhotoVerification` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "PhotoVerification";

-- DropEnum
DROP TYPE "VerificationResult";

-- CreateIndex
CREATE INDEX "Offer_restaurantId_idx" ON "Offer"("restaurantId");

-- CreateIndex
CREATE INDEX "Offer_status_idx" ON "Offer"("status");

-- CreateIndex
CREATE INDEX "Offer_createdAt_idx" ON "Offer"("createdAt");
