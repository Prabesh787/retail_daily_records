import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { fiscalYearController } from './fiscal-year.controller.js';
import {
  createFiscalYearSchema,
  listFiscalYearQuerySchema,
  updateFiscalYearSchema,
} from './fiscal-year.schema.js';

export const fiscalYearRoutes = Router();

fiscalYearRoutes.get(
  '/',
  validate({ query: listFiscalYearQuerySchema }),
  asyncHandler(fiscalYearController.list),
);

// Declared before "/:id" so "active" is not read as an id.
fiscalYearRoutes.get('/active', asyncHandler(fiscalYearController.getActive));

fiscalYearRoutes.get(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(fiscalYearController.getById),
);

fiscalYearRoutes.post(
  '/',
  validate({ body: createFiscalYearSchema }),
  asyncHandler(fiscalYearController.create),
);

fiscalYearRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateFiscalYearSchema }),
  asyncHandler(fiscalYearController.update),
);

fiscalYearRoutes.post(
  '/:id/activate',
  validate({ params: idParamSchema }),
  asyncHandler(fiscalYearController.activate),
);

fiscalYearRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(fiscalYearController.remove),
);
