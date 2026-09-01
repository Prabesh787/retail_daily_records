/**
 * Development seed. Deliberately kept out of the migrations so no fake
 * business data can ever reach a production database.
 *
 *   npm run db:seed
 *
 * It writes:
 *   - one admin user (credentials printed below - change them immediately),
 *     carrying a placeholder shop identity the More screen can then correct
 *   - the current Nepali fiscal year, marked active
 *   - two clearly labelled DEV suppliers and one DEV customer
 *
 * No purchases, payments or sales are seeded: those are the records the shop
 * enters itself, and fake ones would corrupt every report built on top.
 *
 * Re-running is safe - every write is find-or-create.
 */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, UserRole } from './generated/prisma/index.js';
import { hashPassword } from '../modules/auth/password.js';
import { env } from '../config/env.js';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: env.DATABASE_URL }),
});

const ADMIN_EMAIL = 'admin@retails-records.local';
const ADMIN_PASSWORD = 'ChangeMe123!';

/**
 * Shop identity now lives on the user instead of in SHOP_* environment
 * variables. A placeholder is seeded so a fresh development database renders a
 * header rather than four blanks; the real name, address and PAN are typed in
 * the app, on More > Shop details.
 */
const DEV_SHOP = {
  shopName: 'DEV - Retail Records',
  shopAddress: 'Butwal-11, Rupandehi',
  shopPhone: null,
  shopPan: null,
};

const DEV_SUPPLIERS = [
  { name: 'DEV - ABC Textile', phone: '9800000001', address: 'Birgunj', pan: '300000001' },
  { name: 'DEV - Himalayan Fabrics', phone: '9800000002', address: 'Kathmandu', pan: '300000002' },
];

/** Suppliers and customers have no natural unique key, so match on name. */
async function findOrCreate(model, name, data) {
  const existing = await model.findFirst({ where: { name } });
  return existing ?? model.create({ data });
}

async function main() {
  if (env.isProduction) {
    throw new Error('Refusing to seed a production database.');
  }

  const admin = await prisma.user.upsert({
    where: { email: ADMIN_EMAIL },
    update: {},
    create: {
      name: 'Shop Admin',
      email: ADMIN_EMAIL,
      passwordHash: await hashPassword(ADMIN_PASSWORD),
      role: UserRole.ADMIN,
      ...DEV_SHOP,
    },
  });

  // Nepali FY 2082/83 starts on 2082-04-01 BS, which is 2025-07-17 AD.
  const fiscalYear = await prisma.fiscalYear.upsert({
    where: { name: '2082/83' },
    update: {},
    create: {
      name: '2082/83',
      startDate: new Date('2025-07-17T00:00:00.000Z'),
      endDate: new Date('2026-07-16T00:00:00.000Z'),
      startDateBs: '2082-04-01',
      endDateBs: '2083-03-31',
      isActive: true,
    },
  });

  const suppliers = [];
  for (const data of DEV_SUPPLIERS) {
    suppliers.push(
      await findOrCreate(prisma.supplier, data.name, {
        ...data,
        remarks: 'Development seed record',
      }),
    );
  }

  const customerName = 'DEV - Walk-in Regular';
  const customer = await findOrCreate(prisma.customer, customerName, {
    name: customerName,
    phone: '9810000000',
    remarks: 'Development seed record',
  });

  console.warn('Seed complete:');
  console.warn(`  admin user  : ${admin.email} / ${ADMIN_PASSWORD}`);
  console.warn(
    `  shop        : ${admin.shopName ?? 'not set - fill it in on More > Shop details'}`,
  );
  console.warn(`  fiscal year : ${fiscalYear.name} (active)`);
  console.warn(`  suppliers   : ${suppliers.map((s) => s.name).join(', ')}`);
  console.warn(`  customer    : ${customer.name}`);
}

main()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
