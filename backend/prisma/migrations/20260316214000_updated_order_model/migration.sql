-- CreateEnum
CREATE TYPE "CollectionMethod" AS ENUM ('PICKUP', 'DELIVERY');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CARD', 'D17', 'CASH');

-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "collectionMethod" "CollectionMethod",
ADD COLUMN     "deliveryAddress" TEXT,
ADD COLUMN     "deliveryFee" DOUBLE PRECISION,
ADD COLUMN     "deliveryPhone" TEXT,
ADD COLUMN     "paymentDetails" "PaymentMethod",
ADD COLUMN     "paymentMethod" TEXT;
