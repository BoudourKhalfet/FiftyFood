-- CreateEnum
CREATE TYPE "VerificationResult" AS ENUM ('PASSED', 'REJECTED', 'WARNING');

-- CreateTable
CREATE TABLE "PhotoVerification" (
    "id" TEXT NOT NULL,
    "restaurantId" TEXT NOT NULL,
    "imageHash" TEXT NOT NULL,
    "result" "VerificationResult" NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "freshnessRating" TEXT NOT NULL DEFAULT 'unknown',
    "messages" TEXT[],
    "imageSizeBytes" INTEGER NOT NULL,
    "mimeType" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PhotoVerification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PhotoVerification_imageHash_idx" ON "PhotoVerification"("imageHash");

-- CreateIndex
CREATE INDEX "PhotoVerification_restaurantId_idx" ON "PhotoVerification"("restaurantId");
