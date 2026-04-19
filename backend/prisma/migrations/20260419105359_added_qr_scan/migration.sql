-- CreateEnum
CREATE TYPE "QrStatus" AS ENUM ('NOT_SCANNED', 'SCANNED', 'USED', 'EXPIRED');

-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "pickupQrExpiresAt" TIMESTAMP(3),
ADD COLUMN     "pickupQrStatus" "QrStatus" NOT NULL DEFAULT 'NOT_SCANNED',
ADD COLUMN     "pickupQrTokenHash" TEXT,
ADD COLUMN     "pickupQrUsedAt" TIMESTAMP(3);
