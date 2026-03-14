-- CreateTable
CREATE TABLE "LegalAgreement" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "acceptedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "signerName" TEXT NOT NULL,

    CONSTRAINT "LegalAgreement_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "LegalAgreement" ADD CONSTRAINT "LegalAgreement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
