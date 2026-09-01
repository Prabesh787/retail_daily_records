import { z } from 'zod';
import { UserRole } from '../../database/generated/prisma/index.js';
import {
  optionalText,
  paginationQuerySchema,
  requiredText,
} from '../../common/schemas/common.schema.js';

/**
 * The shop this account trades as. It sits on the user rather than in SHOP_*
 * environment variables so it can be edited from the app; an admin can set it
 * when creating an account, and the account holder can correct it themselves
 * through PATCH /auth/me.
 */
const shopFields = {
  shopName: optionalText(180),
  shopAddress: optionalText(255),
  shopPhone: optionalText(30),
  shopPan: optionalText(30),
};

export const roleEnum = z.enum(Object.values(UserRole));

export const createUserSchema = z.object({
  name: requiredText(120, 'Name is required'),
  email: z.email('A valid email address is required').max(180).toLowerCase(),
  password: z.string().min(8, 'Password must be at least 8 characters').max(128),
  role: roleEnum.default(UserRole.USER),
  ...shopFields,
});

export const updateUserSchema = z
  .object({
    name: requiredText(120).optional(),
    email: z.email().max(180).toLowerCase().optional(),
    role: roleEnum.optional(),
    isActive: z.boolean().optional(),
    ...shopFields,
  })
  // Without this, an unsent shop field would arrive as an explicit null and
  // wipe the column: `optionalText` reads a missing key as "clear it", which is
  // right for a create and wrong for a patch.
  .partial();

export const changePasswordSchema = z.object({
  password: z.string().min(8, 'Password must be at least 8 characters').max(128),
});

export const listUserQuerySchema = paginationQuerySchema.extend({
  role: roleEnum.optional(),
});
