import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { reportController } from './report.controller.js';
import { dashboardQuerySchema, supplierOutstandingQuerySchema } from './report.schema.js';

export const reportRoutes = Router();

reportRoutes.get(
  '/dashboard',
  validate({ query: dashboardQuerySchema }),
  asyncHandler(reportController.dashboard),
);

reportRoutes.get(
  '/supplier-outstanding',
  validate({ query: supplierOutstandingQuerySchema }),
  asyncHandler(reportController.supplierOutstanding),
);
