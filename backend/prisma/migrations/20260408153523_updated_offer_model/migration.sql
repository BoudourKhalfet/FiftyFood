/*
  Warnings:

  - Added the required column `pickupDateTime` to the `Offer` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "Offer" ADD COLUMN     "pickupDateTime" TIMESTAMP(3) NOT NULL;
