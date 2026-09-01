import bcrypt from 'bcryptjs';
import { env } from '../../config/env.js';

/**
 * Password hashing lives here rather than in the user service so the login
 * flow and the user-management flow share one implementation and one cost
 * factor.
 *
 * @param {string} plainPassword
 */
export function hashPassword(plainPassword) {
  return bcrypt.hash(plainPassword, env.BCRYPT_SALT_ROUNDS);
}

/**
 * @param {string} plainPassword
 * @param {string} passwordHash
 */
export function verifyPassword(plainPassword, passwordHash) {
  return bcrypt.compare(plainPassword, passwordHash);
}
