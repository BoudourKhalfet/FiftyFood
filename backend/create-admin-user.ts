import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  try {
    // Check if admin exists
    const existingAdmin = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });

    if (existingAdmin) {
      console.log('Admin user already exists:', existingAdmin.email);
      return;
    }

    // Create admin user
    const hashedPassword = await bcrypt.hash('admin123456', 10);
    
    const admin = await prisma.user.create({
      data: {
        email: 'admin@fiftyfood.com',
        passwordHash: hashedPassword,
        role: 'ADMIN',
        status: 'APPROVED',
        emailVerifiedAt: new Date(),
      },
    });

    console.log('Admin user created successfully:');
    console.log({
      id: admin.id,
      email: admin.email,
      role: admin.role,
      status: admin.status,
      password: 'admin123456',
    });
  } catch (error) {
    console.error('Error creating admin:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
