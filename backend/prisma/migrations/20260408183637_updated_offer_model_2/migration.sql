/*
  Warnings:

  - The `category` column on the `Offer` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- CreateEnum
CREATE TYPE "Category" AS ENUM ('BAKERY', 'CAFE', 'GRILL', 'FAST_FOOD', 'VEGETARIAN', 'HALAL', 'SEAFOOD', 'SUSHI', 'PIZZA', 'BURGER', 'BBQ', 'HEALTHY', 'DESSERT', 'STREET_FOOD', 'SANDWICHES', 'SALAD', 'PASTA', 'BREAKFAST', 'FINE_DINING', 'BRUNCH');

-- AlterTable
ALTER TABLE "Offer" DROP COLUMN "category",
ADD COLUMN     "category" "Category"[];
