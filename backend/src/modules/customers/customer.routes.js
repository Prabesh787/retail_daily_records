import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { customerController } from './customer.controller.js';
import {
  createCustomerSchema,
  listCustomerQuerySchema,
  updateCustomerSchema,
} from './customer.schema.js';

export const customerRoutes = Router();

customerRoutes.get(
  '/',
  validate({ query: listCustomerQuerySchema }),
  asyncHandler(customerController.list),
);

customerRoutes.get(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(customerController.getById),
);

customerRoutes.post(
  '/',
  validate({ body: createCustomerSchema }),
  asyncHandler(customerController.create),
);

customerRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateCustomerSchema }),
  asyncHandler(customerController.update),
);

customerRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(customerController.remove),
);
