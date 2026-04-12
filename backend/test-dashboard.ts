import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  try {
    console.log('Checking database records...');
    const userCount = await prisma.user.count();
    const orderCount = await prisma.order.count();
    const reviewCount = await prisma.review.count();
    const restaurantCount = await prisma.user.count({ where: { role: 'RESTAURANT' } });

    console.log('Database Stats:', {
      users: userCount,
      restaurants: restaurantCount,
      orders: orderCount,
      reviews: reviewCount,
    });

    // Get admin user
    const adminUser = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });

    if (adminUser) {
      console.log('\nAdmin user found:', {
        id: adminUser.id,
        email: adminUser.email,
        role: adminUser.role,
        status: adminUser.status,
      });
    } else {
      console.log('\nNo admin user found in database');
      
      // List all users
      const users = await prisma.user.findMany({
        select: {
          id: true,
          email: true,
          role: true,
          status: true,
        },
      });
      
      console.log('All users in database:', users);
    }
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
