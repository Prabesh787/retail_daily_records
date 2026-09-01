import { ValidationError } from '../errors/index.js';

/**
 * @param {import('zod').ZodError} error
 * @param {string} source
 */
function toDetails(error, source) {
  return error.issues.map((issue) => ({
    field: [source, ...issue.path.map(String)].filter(Boolean).join('.'),
    message: issue.message,
  }));
}

/**
 * Validates the request against Zod schemas and replaces the raw request parts
 * with the parsed result, so controllers always receive trimmed, coerced
 * values rather than the strings Express hands over.
 *
 * `req.query` is getter-only in Express 5, so the parsed query is published on
 * `req.validatedQuery` and read back through `validatedQuery(req)`.
 *
 * @param {{ body?: import('zod').ZodType, query?: import('zod').ZodType, params?: import('zod').ZodType }} schemas
 * @returns {import('express').RequestHandler}
 */
export function validate(schemas) {
  return (req, _res, next) => {
    const details = [];

    if (schemas.params) {
      const result = schemas.params.safeParse(req.params);
      if (result.success) req.params = result.data;
      else details.push(...toDetails(result.error, 'params'));
    }

    if (schemas.query) {
      const result = schemas.query.safeParse(req.query);
      if (result.success) {
        Object.defineProperty(req, 'validatedQuery', {
          value: result.data,
          configurable: true,
          enumerable: true,
          writable: true,
        });
      } else {
        details.push(...toDetails(result.error, 'query'));
      }
    }

    if (schemas.body) {
      const result = schemas.body.safeParse(req.body);
      if (result.success) req.body = result.data;
      else details.push(...toDetails(result.error, 'body'));
    }

    if (details.length > 0) {
      next(new ValidationError('Request validation failed', details));
      return;
    }

    next();
  };
}

/**
 * Reads the query object that `validate()` parsed for this request.
 *
 * The client sends `?q=` for free-text search while the schemas and
 * repositories call it `search`. Folding the alias in here means the two names
 * meet in exactly one place instead of in every `buildWhere`.
 *
 * @param {import('express').Request} req
 */
export function validatedQuery(req) {
  const query = req.validatedQuery ?? {};
  if (query.q === undefined || query.search !== undefined) return query;
  const { q, ...rest } = query;
  return { ...rest, search: q };
}
