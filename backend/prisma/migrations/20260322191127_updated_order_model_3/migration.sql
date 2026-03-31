-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "livreurId" TEXT;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_livreurId_fkey" FOREIGN KEY ("livreurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
