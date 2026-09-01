import { z } from 'zod';
import {
  optionalText,
  paginationQuerySchema,
  requiredText,
} from '../../common/schemas/common.schema.js';

export const createCustomerSchema = z.object({
  name: requiredText(180, 'Customer name is required'),
  phone: optionalText(30),
  address: optionalText(255),
  pan: optionalText(30),
  remarks: optionalText(2000),
});

export const updateCustomerSchema = createCustomerSchema.partial();

export const listCustomerQuerySchema = paginationQuerySchema;
