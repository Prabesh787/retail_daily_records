import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { saleController } from './sale.controller.js';
import {
  createSaleSchema,
  dayBookQuerySchema,
  listSaleQuerySchema,
  updateSaleSchema,
} from './sale.schema.js';

export const saleRoutes = Router();

saleRoutes.get('/', validate({ query: listSaleQuerySchema }), asyncHandler(saleController.list));

// Declared before "/:id" so "day-book" is not read as an id.
saleRoutes.get(
  '/day-book',
  validate({ query: dayBookQuerySchema }),
  asyncHandler(saleController.dayBook),
);

saleRoutes.get('/:id', validate({ params: idParamSchema }), asyncHandler(saleController.getById));

saleRoutes.post('/', validate({ body: createSaleSchema }), asyncHandler(saleController.create));

saleRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateSaleSchema }),
  asyncHandler(saleController.update),
);

saleRoutes.delete('/:id', validate({ params: idParamSchema }), asyncHandler(saleController.remove));
