import { createApp } from './app.js';
import { env, logger } from './config/index.js';
import { connectDatabase, disconnectDatabase } from './database/prisma-client.js';

/**
 * Boot sequence: verify the database first, then start listening. A server
 * that accepts requests it cannot serve is worse than one that fails loudly.
 */
async function bootstrap() {
  await connectDatabase();

  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info(
      { port: env.PORT, env: env.NODE_ENV, api: env.API_PREFIX },
      `Server listening on http://localhost:${env.PORT}${env.API_PREFIX}`,
    );
  });

  /** Finish in-flight requests, then release the connection pool. */
  const shutdown = (signal) => {
    logger.info({ signal }, 'Shutting down');
    server.close(async () => {
      await disconnectDatabase();
      process.exit(0);
    });
    // Do not hang forever on a stuck connection.
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  process.on('unhandledRejection', (reason) => {
    logger.error({ err: reason }, 'Unhandled promise rejection');
  });
  process.on('uncaughtException', (error) => {
    logger.fatal({ err: error }, 'Uncaught exception - exiting');
    process.exit(1);
  });
}

bootstrap().catch((error) => {
  logger.fatal({ err: error }, 'Failed to start the server');
  process.exit(1);
});
