-- CreateEnum
CREATE TYPE "EstablishmentType" AS ENUM ('FAST_FOOD', 'CAFE', 'BAKERY', 'RESTAURANT', 'HOTEL');

-- CreateEnum
CREATE TYPE "OwnershipType" AS ENUM ('OWNER', 'MANAGER');

-- CreateEnum
CREATE TYPE "PayoutMethod" AS ENUM ('BANK_TRANSFER', 'MOBILE_WALLET', 'CASH', 'OTHER');

-- CreateTable
CREATE TABLE "RestaurantProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "restaurantName" TEXT,
    "establishmentType" "EstablishmentType",
    "phone" TEXT,
    "address" TEXT,
    "city" TEXT,
    "logoUrl" TEXT,
    "coverImageUrl" TEXT,
    "legalEntityName" TEXT,
    "registrationNumberRNE" TEXT,
    "ownershipType" "OwnershipType",
    "businessRegistrationDocumentUrl" TEXT,
    "hygieneCertificateUrl" TEXT,
    "proofOfOwnershipOrLeaseUrl" TEXT,
    "payoutMethod" "PayoutMethod",
    "payoutDetails" JSONB,
    "identityCompletedAt" TIMESTAMP(3),
    "legalCompletedAt" TIMESTAMP(3),
    "payoutCompletedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RestaurantProfile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "RestaurantProfile_userId_key" ON "RestaurantProfile"("userId");

-- AddForeignKey
ALTER TABLE "RestaurantProfile" ADD CONSTRAINT "RestaurantProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
