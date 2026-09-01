import { ZodError } from 'zod';
import { Prisma } from '../../database/generated/prisma/index.js';
import { env, logger } from '../../config/index.js';
import {
  AppError,
  DuplicateResourceError,
  ErrorCode,
  NotFoundError,
  ValidationError,
} from '../errors/index.js';

/**
 * Turns anything thrown anywhere in the application into a known AppError, so
 * exactly one response shape leaves the server.
 *
 * @param {unknown} err
 * @returns {AppError}
 */
function normalize(err) {
  if (err instanceof AppError) return err;

  if (err instanceof ZodError) {
    return new ValidationError(
      'Validation failed',
      err.issues.map((issue) => ({
        field: issue.path.map(String).join('.'),
        message: issue.message,
      })),
    );
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002': {
        // Unique constraint. `target` names the columns that collided.
        const target = err.meta?.target ?? [];
        const fields = Array.isArray(target) ? target.join(', ') : String(target);
        return new DuplicateResourceError('A record with these values already exists', [
          { field: fields || undefined, message: 'Must be unique' },
        ]);
      }
      case 'P2003':
        return new AppError(
          'A referenced record does not exist',
          400,
          ErrorCode.BUSINESS_RULE_VIOLATION,
          [{ field: err.meta?.field_name, message: 'Invalid reference' }],
        );
      case 'P2025':
        return new NotFoundError('Record');
      default:
        return new AppError(
          'A database error occurred',
          500,
          ErrorCode.DATABASE_ERROR,
          env.isProduction ? [] : [{ message: `Prisma ${err.code}` }],
        );
    }
  }

  if (err instanceof Prisma.PrismaClientValidationError) {
    return new AppError('Invalid database query', 500, ErrorCode.DATABASE_ERROR);
  }

  // Malformed JSON body, rejected by express.json().
  if (err instanceof SyntaxError && 'body' in err) {
    return new ValidationError('Request body is not valid JSON');
  }

  // Multer surfaces upload problems with a `code` string.
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return new AppError(
      `File exceeds the maximum upload size of ${env.MAX_UPLOAD_SIZE_MB}MB`,
      413,
      ErrorCode.PAYLOAD_TOO_LARGE,
    );
  }

  const message = err instanceof Error ? err.message : 'Unknown error';
  return new AppError(
    env.isProduction ? 'Something went wrong' : message,
    500,
    ErrorCode.INTERNAL_ERROR,
  );
}

/**
 * Catch-all for unmatched routes. Registered after every router.
 *
 * @type {import('express').RequestHandler}
 */
export const notFoundHandler = (req, _res, next) => {
  next(new NotFoundError(`Route ${req.method} ${req.originalUrl}`));
};

/**
 * The single place where an error becomes an HTTP response. Must stay the last
 * `app.use()`, and must keep all four parameters for Express to recognise it
 * as error middleware.
 *
 * @type {import('express').ErrorRequestHandler}
 */
export const errorHandler = (err, req, res, _next) => {
  const appError = normalize(err);

  const payload = {
    requestId: req.requestId,
    method: req.method,
    url: req.originalUrl,
    statusCode: appError.statusCode,
    code: appError.code,
    err: err instanceof Error ? { message: err.message, stack: err.stack } : err,
  };

  // 501 is an expected placeholder while modules are still being built, not a
  // fault, so it stays out of the error stream.
  const isFault = appError.statusCode >= 500 && appError.code !== ErrorCode.NOT_IMPLEMENTED;
  if (isFault) logger.error(payload, appError.message);
  else logger.warn(payload, appError.message);

  res.status(appError.statusCode).json({
    success: false,
    message: appError.message,
    code: appError.code,
    errors: appError.details,
  });
};
