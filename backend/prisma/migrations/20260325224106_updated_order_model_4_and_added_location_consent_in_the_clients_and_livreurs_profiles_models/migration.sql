-- AlterTable
ALTER TABLE "ClientProfile" ADD COLUMN     "locationConsentGiven" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "locationConsentGivenAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "LivreurProfile" ADD COLUMN     "locationConsentGiven" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "locationConsentGivenAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "clientLocation" TEXT,
ADD COLUMN     "delivererLocation" TEXT;
