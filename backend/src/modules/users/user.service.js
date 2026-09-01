import { NotFoundError } from '../../common/errors/index.js';
import { serializeUser } from '../../common/serializers/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { prisma } from '../../database/prisma-client.js';
import { hashPassword } from '../auth/password.js';

/**
 * `passwordHash` must never leave the service layer, so every read goes
 * through this projection rather than returning the raw row.
 *
 * The four `shop*` columns are part of it because `serializeUser` folds them
 * into the nested `shop` object the client reads. They live on the user rather
 * than in configuration so the shop name and PAN can be corrected from the app.
 */
const publicFields = {
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

export const userService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const where = {
      ...(query.role ? { role: query.role } : {}),
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { email: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      prisma.user.findMany({
        where,
        select: publicFields,
        orderBy: { createdAt: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      prisma.user.count({ where }),
    ]);

    return { items: items.map(serializeUser), meta: buildPaginationMeta(pagination, total) };
  },

  async getById(id) {
    const user = await prisma.user.findUnique({ where: { id }, select: publicFields });
    if (!user) throw new NotFoundError('User', id);
    return serializeUser(user);
  },

  async create(dto) {
    const { password, ...rest } = dto;
    const passwordHash = await hashPassword(password);
    return serializeUser(
      await prisma.user.create({ data: { ...rest, passwordHash }, select: publicFields }),
    );
  },

  async update(id, dto) {
    await this.getById(id);
    return serializeUser(
      await prisma.user.update({ where: { id }, data: dto, select: publicFields }),
    );
  },

  async changePassword(id, password) {
    await this.getById(id);
    const passwordHash = await hashPassword(password);
    return serializeUser(
      await prisma.user.update({ where: { id }, data: { passwordHash }, select: publicFields }),
    );
  },

  /**
   * Users are deactivated, never deleted: their id is stamped on every
   * purchase, payment and sale they recorded.
   */
  async deactivate(id) {
    await this.getById(id);
    return serializeUser(
      await prisma.user.update({
        where: { id },
        data: { isActive: false },
        select: publicFields,
      }),
    );
  },
};
