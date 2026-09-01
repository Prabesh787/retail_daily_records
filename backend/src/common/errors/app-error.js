/** Machine-readable error codes returned in the `code` field of a failure. */
export const ErrorCode = Object.freeze({
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  NOT_FOUND: 'NOT_FOUND',
  DUPLICATE_RESOURCE: 'DUPLICATE_RESOURCE',
  BUSINESS_RULE_VIOLATION: 'BUSINESS_RULE_VIOLATION',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  DATABASE_ERROR: 'DATABASE_ERROR',
  NOT_IMPLEMENTED: 'NOT_IMPLEMENTED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
});

/**
 * @typedef {object} ErrorDetail
 * @property {string} [field]   Dotted path of the offending field.
 * @property {string} message   Human readable explanation.
 */

/**
 * Base class for every error the application raises deliberately. Anything
 * that is an AppError is safe to show to the client; anything that is not gets
 * flattened into a generic 500 by the error handler.
 */
export class AppError extends Error {
  /**
   * @param {string} message
   * @param {number} [statusCode]
   * @param {string} [code]
   * @param {ErrorDetail[]} [details]
   */
  constructor(message, statusCode = 500, code = ErrorCode.INTERNAL_ERROR, details = []) {
    super(message);
    this.name = new.target.name;
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, new.target);
  }
}

export class ValidationError extends AppError {
  /**
   * @param {string} [message]
   * @param {ErrorDetail[]} [details]
   */
  constructor(message = 'Validation failed', details = []) {
    super(message, 422, ErrorCode.VALIDATION_ERROR, details);
  }
}

export class NotFoundError extends AppError {
  /**
   * @param {string} [resource]
   * @param {string} [identifier]
   */
  constructor(resource = 'Resource', identifier) {
    super(
      identifier
        ? `${resource} with id "${identifier}" was not found`
        : `${resource} was not found`,
      404,
      ErrorCode.NOT_FOUND,
    );
  }
}

export class DuplicateResourceError extends AppError {
  /**
   * @param {string} [message]
   * @param {ErrorDetail[]} [details]
   */
  constructor(message = 'Resource already exists', details = []) {
    super(message, 409, ErrorCode.DUPLICATE_RESOURCE, details);
  }
}

/** Raised when the data is well-formed but breaks a rule of the domain. */
export class BusinessRuleError extends AppError {
  /**
   * @param {string} message
   * @param {ErrorDetail[]} [details]
   */
  constructor(message, details = []) {
    super(message, 400, ErrorCode.BUSINESS_RULE_VIOLATION, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication is required') {
    super(message, 401, ErrorCode.UNAUTHORIZED);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'You do not have permission to perform this action') {
    super(message, 403, ErrorCode.FORBIDDEN);
  }
}

export class PayloadTooLargeError extends AppError {
  constructor(message = 'The uploaded file is too large') {
    super(message, 413, ErrorCode.PAYLOAD_TOO_LARGE);
  }
}

export class DatabaseError extends AppError {
  /**
   * @param {string} [message]
   * @param {ErrorDetail[]} [details]
   */
  constructor(message = 'A database error occurred', details = []) {
    super(message, 500, ErrorCode.DATABASE_ERROR, details);
  }
}

/** Placeholder for endpoints that exist as routes but carry no logic yet. */
export class NotImplementedError extends AppError {
  constructor(what = 'This endpoint') {
    super(`${what} is not implemented yet`, 501, ErrorCode.NOT_IMPLEMENTED);
  }
}
