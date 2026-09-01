import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import { env } from './config/index.js';
import { errorHandler, notFoundHandler } from './common/middleware/error-handler.js';
import { httpLogger, requestId } from './common/middleware/request-context.js';
import { apiRouter } from './routes/index.js';

/**
 * Builds the Express application. Kept separate from server.js so the app can
 * be imported by tests without opening a port.
 */
export function createApp() {
  const app = express();

  // Behind nginx or any reverse proxy, so client IPs and protocol are correct.
  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  app.use(helmet());
  app.use(
    cors({
      origin: env.corsOrigins,
      credentials: true,
      exposedHeaders: ['X-Request-Id'],
    }),
  );
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  app.use(requestId);
  app.use(httpLogger);

  // Liveness probe, outside the versioned API.
  app.get('/health', (_req, res) => {
    res.json({
      success: true,
      message: 'Service is healthy',
      data: { status: 'ok', environment: env.NODE_ENV, uptime: Math.round(process.uptime()) },
    });
  });

  app.use(env.API_PREFIX, apiRouter);

  // Order matters: unmatched route first, then the single error responder.
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
