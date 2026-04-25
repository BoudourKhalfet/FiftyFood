/*
  Warnings:

  - The values [ITALIAN,JAPANESE,BURGERS,VEGAN] on the enum `CuisinePreference` will be removed. If these variants are still used in the database, this will fail.
  - You are about to drop the column `dietaryRestrictions` on the `ClientProfile` table. All the data in the column will be lost.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "CuisinePreference_new" AS ENUM ('BAKERY', 'CAFE', 'GRILL', 'FAST_FOOD', 'VEGETARIAN', 'HALAL', 'SEAFOOD', 'SUSHI', 'PIZZA', 'BURGER', 'BBQ', 'HEALTHY', 'DESSERT', 'STREET_FOOD', 'SANDWICHES', 'SALAD', 'PASTA', 'BREAKFAST', 'FINE_DINING', 'BRUNCH');
ALTER TABLE "ClientProfile" ALTER COLUMN "cuisinePreferences" TYPE "CuisinePreference_new"[] USING ("cuisinePreferences"::text::"CuisinePreference_new"[]);
ALTER TYPE "CuisinePreference" RENAME TO "CuisinePreference_old";
ALTER TYPE "CuisinePreference_new" RENAME TO "CuisinePreference";
DROP TYPE "public"."CuisinePreference_old";
COMMIT;

-- AlterTable
ALTER TABLE "ClientProfile" DROP COLUMN "dietaryRestrictions";

-- DropEnum
DROP TYPE "DietaryRestriction";
