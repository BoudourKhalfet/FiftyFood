-- CreateEnum
CREATE TYPE "ClientType" AS ENUM ('NORMAL', 'PRO');

-- AlterTable
ALTER TABLE "ClientProfile" ADD COLUMN     "clientType" "ClientType" NOT NULL DEFAULT 'NORMAL',
ADD COLUMN     "fiscalNumber" TEXT,
ADD COLUMN     "proAddress" TEXT,
ADD COLUMN     "proPhone" TEXT,
ADD COLUMN     "societyName" TEXT;
