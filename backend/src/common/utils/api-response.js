/**
 * The API returns exactly two envelope shapes.
 *
 * Success: { success: true,  message, data, meta? }
 * Failure: { success: false, message, code, errors: [] }
 *
 * The failure shape is produced centrally by the error middleware.
 */

/**
 * @param {import('express').Response} res
 * @param {unknown} data
 * @param {string} [message]
 * @param {number} [statusCode]
 * @param {object} [meta] Pagination metadata, when the payload is a page.
 */
export function sendSuccess(res, data, message = 'Success', statusCode = 200, meta) {
  const body = { success: true, message, data };
  if (meta) body.meta = meta;
  return res.status(statusCode).json(body);
}

/**
 * @param {import('express').Response} res
 * @param {unknown} data
 * @param {string} [message]
 */
export function sendCreated(res, data, message = 'Created successfully') {
  return sendSuccess(res, data, message, 201);
}

/** @param {import('express').Response} res */
export function sendNoContent(res) {
  return res.status(204).send();
}
