import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL!,
});

const prisma = new PrismaClient({ adapter });

async function main() {
  const table = await prisma.restaurantTable.create({
    data: { tableNumber: 1, qrCode: 'table-1-qr' },
  });
  console.log('Created table:', table);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());