/*
  Warnings:

  - The `categories` column on the `Offer` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- AlterTable
ALTER TABLE "LivreurProfile" ADD COLUMN     "lastOnlineAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Offer" DROP COLUMN "categories",
ADD COLUMN     "categories" TEXT[] DEFAULT ARRAY[]::TEXT[];
