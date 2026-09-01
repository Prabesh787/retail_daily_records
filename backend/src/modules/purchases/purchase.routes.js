import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { purchaseController } from './purchase.controller.js';
import {
  createPurchaseSchema,
  listPurchaseQuerySchema,
  updatePurchaseSchema,
} from './purchase.schema.js';

export const purchaseRoutes = Router();

purchaseRoutes.get(
  '/',
  validate({ query: listPurchaseQuerySchema }),
  asyncHandler(purchaseController.list),
);

purchaseRoutes.get(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(purchaseController.getById),
);

purchaseRoutes.post(
  '/',
  validate({ body: createPurchaseSchema }),
  asyncHandler(purchaseController.create),
);

purchaseRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updatePurchaseSchema }),
  asyncHandler(purchaseController.update),
);

purchaseRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(purchaseController.remove),
);
