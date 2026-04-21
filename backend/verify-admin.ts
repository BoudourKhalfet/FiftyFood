import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  try {
    // Find admin user
    const admin = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });

    if (!admin) {
      console.log('❌ No admin user found');
      return;
    }

    console.log('\n📋 Admin User Details:');
    console.log('─'.repeat(50));
    console.log(`Email: ${admin.email}`);
    console.log(`Role: ${admin.role}`);
    console.log(`Status: ${admin.status}`);
    console.log(`Email Verified: ${admin.emailVerifiedAt ? '✅ Yes' : '❌ No'}`);
    console.log(`Created At: ${admin.createdAt}`);

    // Check if status is APPROVED
    if (admin.status !== 'APPROVED') {
      console.log('\n⚠️  Admin status is not APPROVED!');
      console.log('Updating status to APPROVED...');
      
      const updated = await prisma.user.update({
        where: { id: admin.id },
        data: { status: 'APPROVED' },
      });

      console.log('✅ Admin status updated to APPROVED');
    } else {
      console.log('\n✅ Admin status is already APPROVED');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
