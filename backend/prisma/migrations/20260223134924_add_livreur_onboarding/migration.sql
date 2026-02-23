-- CreateTable
CREATE TABLE "LivreurProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "fullName" TEXT,
    "phone" TEXT,
    "vehicleType" TEXT,
    "zone" TEXT,
    "photoUrl" TEXT,
    "cinOrPassportNumber" TEXT,
    "cinOrPassportPhotoUrl" TEXT,
    "licensePhotoUrl" TEXT,
    "insurancePhotoUrl" TEXT,
    "bankAccountNumber" TEXT,
    "bankRibUrl" TEXT,
    "termsAcceptedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LivreurProfile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "LivreurProfile_userId_key" ON "LivreurProfile"("userId");

-- AddForeignKey
ALTER TABLE "LivreurProfile" ADD CONSTRAINT "LivreurProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
