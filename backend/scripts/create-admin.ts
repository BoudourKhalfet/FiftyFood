import { PrismaClient, Role, AccountStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const email = process.env.ADMIN_EMAIL ?? 'admin@fiftyfood.com';
  const password = process.env.ADMIN_PASSWORD ?? 'Admin123!';
  const passwordHash = await bcrypt.hash(password, 10);

  const admin = await prisma.user.upsert({
    where: { email },
    update: {
      role: Role.ADMIN,
      status: AccountStatus.APPROVED,
      emailVerifiedAt: new Date(),
      passwordHash,
    },
    create: {
      email,
      passwordHash,
      role: Role.ADMIN,
      status: AccountStatus.APPROVED,
      emailVerifiedAt: new Date(),
    },
    select: { id: true, email: true, role: true, status: true },
  });

  console.log('Admin ready:', admin);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => prisma.$disconnect());
