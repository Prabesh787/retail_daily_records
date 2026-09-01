/**
 * Wraps an async controller so a rejected promise reaches the error
 * middleware. Express 5 forwards rejections on its own, but wrapping keeps the
 * behaviour explicit and identical for every route.
 *
 * @param {(req: import('express').Request, res: import('express').Response, next: import('express').NextFunction) => Promise<unknown>} fn
 * @returns {import('express').RequestHandler}
 */
export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
