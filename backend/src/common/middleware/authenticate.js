import jwt from 'jsonwebtoken';
import { env, logger } from '../../config/index.js';
import { prisma } from '../../database/prisma-client.js';
import { ForbiddenError, UnauthorizedError } from '../errors/index.js';

/**
 * JWT authentication.
 *
 * Controllers already read `req.user?.id` for `created_by`, so switching a
 * router from open to protected is a one line change at the mount point - the
 * shape published here is the shape they were written against.
 *
 * `passwordHash` is excluded from the projection, so `req.user` is always safe
 * to serialise straight into a response.
 */
const publicUserFields = {
  id: true,
  name: true,
  email: true,
  role: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
};

/** Warned about once per boot rather than once per request. */
let devFallbackWarned = false;

/**
 * @param {import('express').Request} req
 * @returns {string | null}
 */
function readBearerToken(req) {
  const header = req.header('authorization');
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (!token || scheme.toLowerCase() !== 'bearer') return null;
  return token.trim() || null;
}

/**
 * Signs the access token handed out by POST /auth/login.
 *
 * @param {{ id: string, email: string, role: string }} user
 */
export function signAccessToken(user) {
  return jwt.sign({ sub: user.id, email: user.email, role: user.role }, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN,
  });
}

/**
 * Verifies a token and returns its payload. Every failure mode - expired,
 * tampered, signed with an old secret - becomes the same 401, because telling
 * a caller which one it was only helps an attacker.
 *
 * @param {string} token
 */
export function verifyAccessToken(token) {
  try {
    return jwt.verify(token, env.JWT_SECRET);
  } catch (error) {
    throw new UnauthorizedError(
      error?.name === 'TokenExpiredError'
        ? 'Your session has expired. Please sign in again.'
        : 'Your session is not valid. Please sign in again.',
    );
  }
}

/**
 * The token only carries an id: the account is re-read on every request so a
 * user deactivated five minutes ago cannot keep working on a token that is
 * still technically valid for another day.
 *
 * @param {string} id
 */
async function loadActiveUser(id) {
  const user = await prisma.user.findUnique({ where: { id }, select: publicUserFields });
  if (!user) throw new UnauthorizedError('This account no longer exists.');
  if (!user.isActive) throw new ForbiddenError('This account has been deactivated.');
  return user;
}

/**
 * Development-only stand-in for a signed-in user, so the API can be driven
 * with plain curl and by a frontend that has no login screen yet. `env`
 * pins this to false whenever NODE_ENV is production.
 */
async function devFallbackUser() {
  if (!env.authDevFallback) return null;

  const user = await prisma.user.findFirst({
    where: { isActive: true, role: 'ADMIN' },
    select: publicUserFields,
    orderBy: { createdAt: 'asc' },
  });
  if (!user) return null;

  if (!devFallbackWarned) {
    devFallbackWarned = true;
    logger.warn(
      { user: user.email },
      'AUTH_DEV_FALLBACK is on: unauthenticated requests are being served as this admin',
    );
  }
  return user;
}

/**
 * Populates `req.user` or rejects the request.
 *
 * @type {import('express').RequestHandler}
 */
export async function authenticate(req, _res, next) {
  try {
    const token = readBearerToken(req);

    if (token) {
      const payload = verifyAccessToken(token);
      req.user = await loadActiveUser(payload.sub);
      req.authSource = 'token';
      return next();
    }

    const fallback = await devFallbackUser();
    if (fallback) {
      req.user = fallback;
      req.authSource = 'dev-fallback';
      return next();
    }

    return next(new UnauthorizedError('Authentication is required. Sign in to continue.'));
  } catch (error) {
    return next(error);
  }
}

/**
 * Same as `authenticate`, but a missing or unusable token leaves `req.user`
 * undefined instead of ending the request. For endpoints that answer either
 * way and only enrich the response when they know who is asking.
 *
 * @type {import('express').RequestHandler}
 */
export async function optionalAuthenticate(req, _res, next) {
  try {
    const token = readBearerToken(req);
    if (token) {
      const payload = verifyAccessToken(token);
      req.user = await loadActiveUser(payload.sub);
      req.authSource = 'token';
    } else {
      const fallback = await devFallbackUser();
      if (fallback) {
        req.user = fallback;
        req.authSource = 'dev-fallback';
      }
    }
  } catch {
    // Anonymous is a valid outcome here.
  }
  return next();
}

/**
 * Role gate, applied after `authenticate`.
 *
 * @param {...string} roles
 * @returns {import('express').RequestHandler}
 */
export function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user) return next(new UnauthorizedError());
    if (!roles.includes(req.user.role)) return next(new ForbiddenError());
    return next();
  };
}
