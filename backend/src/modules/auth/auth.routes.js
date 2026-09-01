import { Router } from 'express';
import { authenticate } from '../../common/middleware/authenticate.js';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { authController } from './auth.controller.js';
import { loginSchema, updateProfileSchema } from './auth.schema.js';

export const authRoutes = Router();

authRoutes.post('/login', validate({ body: loginSchema }), asyncHandler(authController.login));

/**
 * `authenticate` is what makes this endpoint answer "who am I". While
 * AUTH_DEV_FALLBACK is on it resolves an unauthenticated request to the first
 * active admin, so the app is usable before a login screen exists.
 */
authRoutes.get('/me', authenticate, asyncHandler(authController.me));

/**
 * Self-service edit of the signed-in account: display name and shop details.
 * It lives here rather than under /users because it needs no id and no admin
 * role - the account being changed is the one holding the token, which is the
 * only way the shopkeeper can fix their own shop name.
 */
authRoutes.patch(
  '/me',
  authenticate,
  validate({ body: updateProfileSchema }),
  asyncHandler(authController.updateMe),
);
