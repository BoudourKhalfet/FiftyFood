-- CreateTable
CREATE TABLE "Complaint" (
    "id" TEXT NOT NULL,
    "orderId" TEXT,
    "complainantId" TEXT NOT NULL,
    "restaurantId" TEXT,
    "delivererId" TEXT,
    "reason" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Complaint_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Complaint_orderId_idx" ON "Complaint"("orderId");

-- CreateIndex
CREATE INDEX "Complaint_restaurantId_idx" ON "Complaint"("restaurantId");

-- CreateIndex
CREATE INDEX "Complaint_delivererId_idx" ON "Complaint"("delivererId");

-- CreateIndex
CREATE INDEX "Complaint_complainantId_idx" ON "Complaint"("complainantId");

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_complainantId_fkey" FOREIGN KEY ("complainantId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_restaurantId_fkey" FOREIGN KEY ("restaurantId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_delivererId_fkey" FOREIGN KEY ("delivererId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
