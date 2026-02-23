-- AlterTable
ALTER TABLE "User" ADD COLUMN     "statusReason" TEXT,
ADD COLUMN     "suspendedAt" TIMESTAMP(3);
