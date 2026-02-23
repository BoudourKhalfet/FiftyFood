/*
  Warnings:

  - You are about to drop the column `cuisinePreferences` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `defaultAddress` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `dietaryRestrictions` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `fullName` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `phone` on the `User` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "User" DROP COLUMN "cuisinePreferences",
DROP COLUMN "defaultAddress",
DROP COLUMN "dietaryRestrictions",
DROP COLUMN "fullName",
DROP COLUMN "phone";

-- CreateTable
CREATE TABLE "ClientProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "fullName" TEXT,
    "phone" TEXT,
    "defaultAddress" TEXT,
    "cuisinePreferences" "CuisinePreference"[],
    "dietaryRestrictions" "DietaryRestriction"[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ClientProfile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ClientProfile_userId_key" ON "ClientProfile"("userId");

-- AddForeignKey
ALTER TABLE "ClientProfile" ADD CONSTRAINT "ClientProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
