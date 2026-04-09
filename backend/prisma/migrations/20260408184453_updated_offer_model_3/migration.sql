/*
  Warnings:

  - You are about to drop the column `category` on the `Offer` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Offer" DROP COLUMN "category",
ADD COLUMN     "categories" "Category"[];
