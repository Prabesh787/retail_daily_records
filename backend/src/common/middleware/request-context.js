import { randomUUID } from 'node:crypto';
import pinoHttp from 'pino-http';
import { logger } from '../../config/index.js';

/**
 * Gives every request a correlation id, echoed back as `X-Request-Id` so a log
 * line can be matched to the response the shopkeeper actually saw.
 *
 * @type {import('express').RequestHandler}
 */
export const requestId = (req, res, next) => {
  const incoming = req.header('x-request-id');
  req.requestId = incoming && incoming.length <= 100 ? incoming : randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  next();
};

/** One structured log line per request, reusing the id assigned above. */
export const httpLogger = pinoHttp({
  logger,
  genReqId: (req) => req.requestId ?? randomUUID(),
  customLogLevel: (_req, res, err) => {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  autoLogging: {
    ignore: (req) => req.url === '/health' || req.url?.endsWith('/health'),
  },
});
