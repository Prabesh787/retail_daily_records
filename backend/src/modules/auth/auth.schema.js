import { z } from 'zod';
import { optionalText, requiredText } from '../../common/schemas/common.schema.js';

export const loginSchema = z.object({
  email: z.email('A valid email address is required').max(180).toLowerCase(),
  password: z.string().min(1, 'Password is required').max(128),
});

/**
 * PATCH /auth/me. Every field is optional so the shop form can send only what
 * it edits, and the shop fields are `optionalText`, which turns a cleared input
 * into NULL rather than into an empty string - "not filled in" has one
 * representation in the column, as it does everywhere else in this API.
 *
 * The lengths match the columns: shop_name 180, shop_address 255, and 30 for
 * the phone and PAN, the same widths suppliers and customers use.
 */
export const updateProfileSchema = z
  .object({
    name: requiredText(120, 'Your name is required').optional(),
    shopName: optionalText(180),
    shopAddress: optionalText(255),
    shopPhone: optionalText(30),
    shopPan: optionalText(30),
  })
  .partial()
  .refine((dto) => Object.keys(dto).length > 0, 'Nothing to update');
