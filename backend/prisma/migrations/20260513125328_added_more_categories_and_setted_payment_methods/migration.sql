/*
  Warnings:

  - The values [CAFE] on the enum `Category` will be removed. If these variants are still used in the database, this will fail.
  - The values [CAFE] on the enum `CuisinePreference` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "Category_new" AS ENUM ('BAKERY', 'GRILL', 'FAST_FOOD', 'VEGETARIAN', 'HALAL', 'SEAFOOD', 'SUSHI', 'PIZZA', 'BURGER', 'BBQ', 'HEALTHY', 'DESSERT', 'STREET_FOOD', 'SANDWICHES', 'SALAD', 'PASTA', 'BREAKFAST', 'FINE_DINING', 'BRUNCH', 'TUNISIAN', 'ITALIAN', 'CHINESE', 'FRIED_FOOD');
ALTER TYPE "Category" RENAME TO "Category_old";
ALTER TYPE "Category_new" RENAME TO "Category";
DROP TYPE "public"."Category_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "CuisinePreference_new" AS ENUM ('BAKERY', 'GRILL', 'FAST_FOOD', 'VEGETARIAN', 'HALAL', 'SEAFOOD', 'SUSHI', 'PIZZA', 'BURGER', 'BBQ', 'HEALTHY', 'DESSERT', 'STREET_FOOD', 'SANDWICHES', 'SALAD', 'PASTA', 'BREAKFAST', 'FINE_DINING', 'BRUNCH', 'TUNISIAN', 'ITALIAN', 'CHINESE', 'FRIED_FOOD');
ALTER TABLE "ClientProfile" ALTER COLUMN "cuisinePreferences" TYPE "CuisinePreference_new"[] USING ("cuisinePreferences"::text::"CuisinePreference_new"[]);
ALTER TYPE "CuisinePreference" RENAME TO "CuisinePreference_old";
ALTER TYPE "CuisinePreference_new" RENAME TO "CuisinePreference";
DROP TYPE "public"."CuisinePreference_old";
COMMIT;

-- AlterEnum
ALTER TYPE "PayoutMethod" ADD VALUE 'EDINAR';
