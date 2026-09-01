import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/index.js';
import { env, logger } from '../config/index.js';

/**
 * Prisma 7 talks to Postgres through a driver adapter, so the connection
 * string is handed to `PrismaPg` here rather than declared in schema.prisma.
 *
 * One client instance is shared by the whole process; it owns the connection
 * pool. `prisma.$transaction(async (tx) => ...)` is the entry point for the
 * multi-write flows described in the README (purchase + initial payments +
 * attachment metadata as one unit).
 */
const adapter = new PrismaPg({ connectionString: env.DATABASE_URL });

export const prisma = new PrismaClient({
  adapter,
  log: env.isDevelopment
    ? [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'warn' },
        { emit: 'event', level: 'error' },
      ]
    : [{ emit: 'event', level: 'error' }],
});

if (env.isDevelopment) {
  prisma.$on('query', (event) => {
    logger.debug({ query: event.query, duration: event.duration }, 'prisma query');
  });
  prisma.$on('warn', (event) => logger.warn({ target: event.target }, event.message));
}

prisma.$on('error', (event) => {
  logger.error({ target: event.target }, event.message);
});

/** Fails fast at boot if the database is unreachable or misconfigured. */
export async function connectDatabase() {
  await prisma.$queryRaw`SELECT 1`;
  logger.info('Database connection established');
}

export async function disconnectDatabase() {
  await prisma.$disconnect();
  logger.info('Database connection closed');
}
