-- DropForeignKey
ALTER TABLE "AccountHistory" DROP CONSTRAINT "AccountHistory_userId_fkey";

-- AddForeignKey
ALTER TABLE "AccountHistory" ADD CONSTRAINT "AccountHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
