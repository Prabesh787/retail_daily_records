import { env } from '../../config/index.js';
import { signAccessToken } from '../../common/middleware/authenticate.js';
import { ForbiddenError, UnauthorizedError } from '../../common/errors/index.js';
import { serializeShop, serializeUser } from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';
import { verifyPassword } from './password.js';

/**
 * Authentication.
 *
 * Token issuing lives here; verifying one and turning it into `req.user` lives
 * in `common/middleware/authenticate.js`, which is what routers apply. The
 * pieces this builds on were already in place: the `users` table with
 * `password_hash` / `role` / `is_active`, the shared hashing in ./password.js,
 * and JWT_SECRET / JWT_EXPIRES_IN validated at boot.
 *
 * There is still no Shop table - one account trades as one shop - but the shop
 * profile is now columns on that account rather than SHOP_* environment
 * variables, so the shopkeeper can correct a misspelt name or a new PAN from
 * the app instead of by editing .env and restarting.
 *
 * `serializeUser` nests the shop inside the user, so the login and profile
 * responses repeat it at the top level as `shop`. That is the key clients read
 * to render a header without a second round trip, and it kept reading the same
 * way when the values moved out of configuration and onto the row.
 */

/**
 * A real bcrypt hash of a passphrase nobody holds. Compared against when the
 * email does not exist, purely so that path costs the same as a wrong password.
 */
const DUMMY_PASSWORD_HASH = '$2b$10$T2ONrLvATRTagWcQb9qXMeADFEayM8dyuqfR.dzs9BU9kKyIt3.re';

/**
 * Never select `passwordHash` into anything that might be serialised. The shop
 * columns are always selected with it: `serializeUser` folds them into `shop`,
 * and a projection that left them out would publish a shop of four nulls that
 * looks like an unfilled form rather than an unasked question.
 */
const publicUserFields = {
  id: true,
  name: true,
  email: true,
  role: true,
  isActive: true,
  shopName: true,
  shopAddress: true,
  shopPhone: true,
  shopPan: true,
  createdAt: true,
  updatedAt: true,
};

export const authService = {
  /**
   * @param {{ email: string, password: string }} credentials
   */
  async login({ email, password }) {
    const user = await prisma.user.findUnique({ where: { email } });

    // One message for "no such account" and for "wrong password": a different
    // answer to each would turn this endpoint into a list of who has an
    // account here.
    const invalid = new UnauthorizedError('The email or password is incorrect.');
    if (!user) {
      // Still spend the hashing time, so a missing account cannot be told from
      // a wrong password by how quickly the answer comes back.
      await verifyPassword(password, DUMMY_PASSWORD_HASH);
      throw invalid;
    }

    if (!(await verifyPassword(password, user.passwordHash))) throw invalid;
    if (!user.isActive) throw new ForbiddenError('This account has been deactivated.');

    return {
      token: signAccessToken(user),
      tokenType: 'Bearer',
      expiresIn: env.JWT_EXPIRES_IN,
      user: this.toPublicUser(user),
      shop: serializeShop(user),
    };
  },

  /**
   * The signed-in user plus the shop they trade as.
   *
   * @param {string | undefined} userId Comes from `req.user`, set by `authenticate`.
   */
  async me(userId) {
    const user = await this.requireActiveUser(userId);
    return { user: serializeUser(user), shop: serializeShop(user) };
  },

  /**
   * What the signed-in user may change about themselves without being an
   * admin: their display name and the shop details printed on their reports.
   * Deliberately not role, isActive or email - those decide what an account can
   * reach, and belong to the admin endpoints under /users.
   *
   * @param {string | undefined} userId
   * @param {object} dto Already validated by `updateProfileSchema`.
   */
  async updateProfile(userId, dto) {
    await this.requireActiveUser(userId);

    const user = await prisma.user.update({
      where: { id: userId },
      data: dto,
      select: publicUserFields,
    });

    return { user: serializeUser(user), shop: serializeShop(user) };
  },

  /**
   * Re-reads the account behind a request and refuses it if that account has
   * gone or been switched off since the token was issued.
   *
   * @param {string | undefined} userId
   */
  async requireActiveUser(userId) {
    if (!userId) throw new UnauthorizedError();

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: publicUserFields,
    });
    if (!user) throw new UnauthorizedError('This account no longer exists.');
    if (!user.isActive) throw new ForbiddenError('This account has been deactivated.');

    return user;
  },

  /** @param {object} user A raw `users` row. */
  toPublicUser(user) {
    return serializeUser(
      Object.fromEntries(Object.keys(publicUserFields).map((key) => [key, user[key]])),
    );
  },
};
