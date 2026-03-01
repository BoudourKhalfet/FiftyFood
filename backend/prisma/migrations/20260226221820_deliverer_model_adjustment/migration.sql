/*
  Warnings:

  - You are about to drop the column `bankAccountNumber` on the `LivreurProfile` table. All the data in the column will be lost.
  - You are about to drop the column `bankRibUrl` on the `LivreurProfile` table. All the data in the column will be lost.
  - You are about to drop the column `cinOrPassportPhotoUrl` on the `LivreurProfile` table. All the data in the column will be lost.
  - You are about to drop the column `insurancePhotoUrl` on the `LivreurProfile` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "LivreurProfile" DROP COLUMN "bankAccountNumber",
DROP COLUMN "bankRibUrl",
DROP COLUMN "cinOrPassportPhotoUrl",
DROP COLUMN "insurancePhotoUrl",
ADD COLUMN     "payoutDetails" JSONB,
ADD COLUMN     "payoutMethod" "PayoutMethod",
ADD COLUMN     "vehicleOwnershipDocUrl" TEXT,
ADD COLUMN     "vehiclePhotoUrl" TEXT;
