/**
 * Creates the first admin on a fresh database.
 *
 *     read -rsp 'Password: ' ADMIN_PASSWORD; echo; export ADMIN_PASSWORD
 *     npm run admin:create -- --name "Shop Owner" --email owner@example.com
 *     unset ADMIN_PASSWORD
 *
 * The seed refuses to touch production, and every user-management endpoint
 * sits behind `authenticate`, so without this there is no way to sign in to a
 * new production install. It only bootstraps: once an active admin exists it
 * refuses, and further accounts are made through POST /users.
 *
 * The password comes from the environment rather than an argument so it never
 * lands in shell history or the process list.
 */

// Printing is how this reports; the lint rule is aimed at leftovers in the API.
/* eslint-disable no-console */
import { parseArgs } from 'node:util';
import { UserRole } from '../src/database/generated/prisma/index.js';
import { prisma } from '../src/database/prisma-client.js';
import { createUserSchema } from '../src/modules/users/user.schema.js';
import { userService } from '../src/modules/users/user.service.js';

const { values } = parseArgs({
  options: {
    name: { type: 'string' },
    email: { type: 'string' },
  },
});

async function main() {
  const existing = await prisma.user.count({ where: { role: UserRole.ADMIN, isActive: true } });
  if (existing > 0) {
    console.error('An active admin already exists. Create further users through POST /users.');
    process.exitCode = 1;
    return;
  }

  // Same rules as POST /users, so the bootstrap admin is no weaker than any other.
  const parsed = createUserSchema.safeParse({
    name: values.name,
    email: values.email,
    password: process.env.ADMIN_PASSWORD,
    role: UserRole.ADMIN,
  });
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      console.error(`  - ${issue.path.join('.')}: ${issue.message}`);
    }
    console.error('Usage: npm run admin:create -- --name "<name>" --email <email>');
    console.error('       with the password exported as ADMIN_PASSWORD.');
    process.exitCode = 1;
    return;
  }

  const admin = await userService.create(parsed.data);
  console.log(`Admin created: ${admin.email} (${admin.id})`);
}

main()
  .catch((error) => {
    console.error('Could not create the admin:', error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
