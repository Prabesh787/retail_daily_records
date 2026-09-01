import pino from 'pino';
import { env } from './env.js';

/**
 * Structured logger. Pretty-printed while developing, plain JSON everywhere
 * else so logs can be shipped to a collector later without touching this file.
 */
export const logger = pino({
  level: env.LOG_LEVEL,
  base: undefined,
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.passwordHash'],
    remove: true,
  },
  ...(env.isDevelopment
    ? {
        transport: {
          target: 'pino-pretty',
          options: { colorize: true, translateTime: 'SYS:HH:MM:ss', ignore: 'pid,hostname' },
        },
      }
    : {}),
});
