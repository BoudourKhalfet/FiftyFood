-- CreateEnum
CREATE TYPE "Role" AS ENUM ('CLIENT', 'LIVREUR', 'RESTAURANT', 'ADMIN');

-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CHANGES_REQUIRED');

-- CreateEnum
CREATE TYPE "DietaryRestriction" AS ENUM ('NO_RESTRICTIONS', 'VEGETARIAN', 'VEGAN', 'GLUTEN_FREE', 'DAIRY_FREE', 'NUT_FREE', 'HALAL');

-- CreateEnum
CREATE TYPE "CuisinePreference" AS ENUM ('ITALIAN', 'JAPANESE', 'HEALTHY', 'BURGERS', 'BAKERY', 'CAFE', 'SANDWICHES', 'VEGAN');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "status" "AccountStatus" NOT NULL DEFAULT 'PENDING',
    "emailVerifiedAt" TIMESTAMP(3),
    "emailVerificationTokenHash" TEXT,
    "emailVerificationExpiresAt" TIMESTAMP(3),
    "fullName" TEXT,
    "phone" TEXT,
    "defaultAddress" TEXT,
    "cuisinePreferences" "CuisinePreference"[],
    "dietaryRestrictions" "DietaryRestriction"[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "User_status_idx" ON "User"("status");
