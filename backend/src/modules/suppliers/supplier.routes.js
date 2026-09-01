import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { supplierController } from './supplier.controller.js';
import {
  createSupplierSchema,
  listSupplierQuerySchema,
  supplierDetailQuerySchema,
  updateSupplierSchema,
} from './supplier.schema.js';

export const supplierRoutes = Router();

supplierRoutes.get(
  '/',
  validate({ query: listSupplierQuerySchema }),
  asyncHandler(supplierController.list),
);

supplierRoutes.get(
  '/:id',
  validate({ params: idParamSchema, query: supplierDetailQuerySchema }),
  asyncHandler(supplierController.getById),
);

supplierRoutes.post(
  '/',
  validate({ body: createSupplierSchema }),
  asyncHandler(supplierController.create),
);

supplierRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateSupplierSchema }),
  asyncHandler(supplierController.update),
);

supplierRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(supplierController.remove),
);
