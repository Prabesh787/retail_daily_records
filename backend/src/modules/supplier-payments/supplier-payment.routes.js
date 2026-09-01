import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { supplierPaymentController } from './supplier-payment.controller.js';
import {
  chequeRegisterQuerySchema,
  clearPaymentSchema,
  createSupplierPaymentSchema,
  listSupplierPaymentQuerySchema,
  updateSupplierPaymentSchema,
} from './supplier-payment.schema.js';

export const supplierPaymentRoutes = Router();

supplierPaymentRoutes.get(
  '/',
  validate({ query: listSupplierPaymentQuerySchema }),
  asyncHandler(supplierPaymentController.list),
);

// Declared before "/:id" so "cheque-register" is not read as an id.
supplierPaymentRoutes.get(
  '/cheque-register',
  validate({ query: chequeRegisterQuerySchema }),
  asyncHandler(supplierPaymentController.chequeRegister),
);

supplierPaymentRoutes.get(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(supplierPaymentController.getById),
);

supplierPaymentRoutes.post(
  '/',
  validate({ body: createSupplierPaymentSchema }),
  asyncHandler(supplierPaymentController.create),
);

supplierPaymentRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateSupplierPaymentSchema }),
  asyncHandler(supplierPaymentController.update),
);

supplierPaymentRoutes.post(
  '/:id/clear',
  validate({ params: idParamSchema, body: clearPaymentSchema }),
  asyncHandler(supplierPaymentController.clear),
);

supplierPaymentRoutes.post(
  '/:id/cancel',
  validate({ params: idParamSchema }),
  asyncHandler(supplierPaymentController.cancel),
);

supplierPaymentRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(supplierPaymentController.remove),
);
