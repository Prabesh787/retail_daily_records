import 'dotenv/config';
import { z } from 'zod';

/**
 * Every environment variable the application reads goes through this schema.
 * Anything missing or malformed stops the process at boot instead of failing
 * at the first request that happens to need it.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  API_PREFIX: z.string().startsWith('/').default('/api/v1'),
  CORS_ORIGIN: z.string().default('*'),

  /**
   * The calendar day the shop is living in. Reports derive "today" from this,
   * not from the server clock's UTC date - Kathmandu is UTC+05:45, so a
   * UTC-derived day would lag behind the shop until 05:45 every morning.
   */
  APP_TIMEZONE: z
    .string()
    .default('Asia/Kathmandu')
    .refine((zone) => {
      try {
        new Intl.DateTimeFormat('en-CA', { timeZone: zone });
        return true;
      } catch {
        return false;
      }
    }, 'APP_TIMEZONE must be a valid IANA timezone, e.g. Asia/Kathmandu'),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  JWT_SECRET: z.string().min(16).default('development-only-secret-change-me'),
  JWT_EXPIRES_IN: z.string().default('1d'),
  BCRYPT_SALT_ROUNDS: z.coerce.number().int().min(4).max(15).default(10),

  /**
   * Development convenience: treat a request that carries no bearer token as
   * the first active admin, so the API can be exercised with plain curl and by
   * a frontend that has no login screen yet. Forced off in production below -
   * it must never be the reason an endpoint is reachable.
   *
   * A plain z.coerce.boolean() would read the string "false" as true, hence
   * the explicit enum.
   */
  AUTH_DEV_FALLBACK: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),

  STORAGE_DRIVER: z.enum(['local', 's3', 'cloudinary']).default('local'),
  LOCAL_STORAGE_PATH: z.string().default('./storage'),
  LOCAL_STORAGE_BASE_URL: z.string().default('http://localhost:4000/files'),
  MAX_UPLOAD_SIZE_MB: z.coerce.number().int().positive().default(10),

  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
    .join('\n');
  // The logger depends on env, so it does not exist yet at this point.
  console.error(`Invalid environment configuration:\n${issues}`);
  console.error('Copy .env.example to .env and fill in the missing values.');
  process.exit(1);
}

const raw = parsed.data;

export const env = Object.freeze({
  ...raw,
  isDevelopment: raw.NODE_ENV === 'development',
  isProduction: raw.NODE_ENV === 'production',
  isTest: raw.NODE_ENV === 'test',
  corsOrigins: raw.CORS_ORIGIN === '*' ? '*' : raw.CORS_ORIGIN.split(',').map((o) => o.trim()),
  maxUploadSizeBytes: raw.MAX_UPLOAD_SIZE_MB * 1024 * 1024,
  /** Never honoured in production, whatever the .env of the day happens to say. */
  authDevFallback: raw.NODE_ENV === 'production' ? false : raw.AUTH_DEV_FALLBACK,
});
