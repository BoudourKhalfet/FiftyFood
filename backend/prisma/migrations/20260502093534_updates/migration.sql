-- AlterTable
ALTER TABLE "LivreurProfile" ADD COLUMN     "cinBackPhotoUrl" TEXT,
ADD COLUMN     "cinFrontPhotoUrl" TEXT,
ADD COLUMN     "cinVerificationStatus" TEXT DEFAULT 'PENDING',
ADD COLUMN     "cinVerifiedAt" TIMESTAMP(3),
ADD COLUMN     "identityVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "identityVerifiedAt" TIMESTAMP(3);
