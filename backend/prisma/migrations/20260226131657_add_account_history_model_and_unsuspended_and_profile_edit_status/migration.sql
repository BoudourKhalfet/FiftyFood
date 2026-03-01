-- CreateEnum
CREATE TYPE "AccountAction" AS ENUM ('SUSPEND', 'UNSUSPEND', 'APPROVE', 'REJECT', 'REQUIRE_CHANGES', 'PROFILE_EDIT');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AccountStatus" ADD VALUE 'UNSUSPEND';
ALTER TYPE "AccountStatus" ADD VALUE 'PROFILE_EDIT';

-- CreateTable
CREATE TABLE "AccountHistory" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "actorRole" TEXT NOT NULL,
    "action" "AccountAction" NOT NULL,
    "field" TEXT,
    "oldValue" TEXT,
    "newValue" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccountHistory_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "AccountHistory" ADD CONSTRAINT "AccountHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
