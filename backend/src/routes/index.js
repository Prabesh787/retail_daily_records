import { Router } from 'express';
import { authenticate } from '../common/middleware/authenticate.js';
import { authRoutes } from '../modules/auth/auth.routes.js';
import { userRoutes } from '../modules/users/user.routes.js';
import { fiscalYearRoutes } from '../modules/fiscal-years/fiscal-year.routes.js';
import { supplierRoutes } from '../modules/suppliers/supplier.routes.js';
import { purchaseRoutes } from '../modules/purchases/purchase.routes.js';
import { supplierPaymentRoutes } from '../modules/supplier-payments/supplier-payment.routes.js';
import { customerRoutes } from '../modules/customers/customer.routes.js';
import { saleRoutes } from '../modules/sales/sale.routes.js';
import { attachmentRoutes } from '../modules/attachments/attachment.routes.js';
import { reportRoutes } from '../modules/reports/report.routes.js';

/**
 * Every module mounts under the versioned prefix (default `/api/v1`).
 *
 * Two things are reachable without a token, and only two: the liveness probe,
 * and `/auth` - which has to be, or there would be no way to obtain a token in
 * the first place. `/auth/login` is open; `/auth/me` applies `authenticate`
 * itself, inside that router.
 *
 * Everything below the `authenticate` line requires a valid bearer token. It is
 * one line rather than one per router so a module added later is protected by
 * default instead of by remembering to.
 */
export const apiRouter = Router();

apiRouter.get('/health', (_req, res) => {
  res.json({ success: true, message: 'API is running', data: { status: 'ok' } });
});

apiRouter.use('/auth', authRoutes);

// Everything past this point needs a signed-in user.
apiRouter.use(authenticate);

apiRouter.use('/users', userRoutes);
apiRouter.use('/fiscal-years', fiscalYearRoutes);
apiRouter.use('/suppliers', supplierRoutes);
apiRouter.use('/purchases', purchaseRoutes);
apiRouter.use('/supplier-payments', supplierPaymentRoutes);
apiRouter.use('/customers', customerRoutes);
apiRouter.use('/sales', saleRoutes);
apiRouter.use('/attachments', attachmentRoutes);
apiRouter.use('/reports', reportRoutes);
