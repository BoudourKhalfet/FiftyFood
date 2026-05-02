/*
  Warnings:

  - The values [CASH] on the enum `PaymentMethod` will be removed. If these variants are still used in the database, this will fail.
  - The `paymentMethod` column on the `Order` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - You are about to drop the column `lastGeocodedAt` on the `RestaurantProfile` table. All the data in the column will be lost.

*/
-- CreateEnum
CREATE TYPE "InteractionType" AS ENUM ('OFFER_VIEW', 'RESTAURANT_VIEW');

-- AlterEnum
BEGIN;
CREATE TYPE "PaymentMethod_new" AS ENUM ('CARD', 'D17', 'PAYPAL');
ALTER TABLE "Order" ALTER COLUMN "paymentMethod" TYPE "PaymentMethod_new" USING ("paymentMethod"::text::"PaymentMethod_new");
ALTER TYPE "PaymentMethod" RENAME TO "PaymentMethod_old";
ALTER TYPE "PaymentMethod_new" RENAME TO "PaymentMethod";
DROP TYPE "public"."PaymentMethod_old";
COMMIT;

-- AlterTable
ALTER TABLE "Order" DROP COLUMN "paymentMethod",
ADD COLUMN     "paymentMethod" "PaymentMethod";

-- AlterTable
ALTER TABLE "RestaurantProfile" DROP COLUMN "lastGeocodedAt";

-- CreateTable
CREATE TABLE "ClientInteraction" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "interactionType" "InteractionType" NOT NULL,
    "offerId" TEXT,
    "restaurantId" TEXT,
    "categories" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "price" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClientInteraction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ClientInteraction_clientId_interactionType_idx" ON "ClientInteraction"("clientId", "interactionType");

-- CreateIndex
CREATE INDEX "ClientInteraction_clientId_createdAt_idx" ON "ClientInteraction"("clientId", "createdAt");
