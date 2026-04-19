-- AlterTable
ALTER TABLE "RestaurantProfile" ADD COLUMN     "lastGeocodedAt" TIMESTAMP(3),
ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION;
