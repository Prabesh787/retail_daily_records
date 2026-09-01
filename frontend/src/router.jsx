import { createBrowserRouter } from 'react-router-dom';
import { AppShell } from '@/components/layout/AppShell';
import { RequireAuth } from '@/components/layout/RequireAuth';
import { LoginScreen } from '@/features/auth/LoginScreen';
import { DashboardScreen } from '@/features/dashboard/DashboardScreen';
import { PurchasesScreen } from '@/features/purchases/PurchasesScreen';
import { PurchaseDetailScreen } from '@/features/purchases/PurchaseDetailScreen';
import { PurchaseFormScreen } from '@/features/purchases/PurchaseFormScreen';
import { SalesScreen } from '@/features/sales/SalesScreen';
import { SaleDetailScreen } from '@/features/sales/SaleDetailScreen';
import { SaleFormScreen } from '@/features/sales/SaleFormScreen';
import { SaleDayScreen } from '@/features/sales/SaleDayScreen';
import { SuppliersScreen } from '@/features/suppliers/SuppliersScreen';
import { SupplierFormScreen } from '@/features/suppliers/SupplierFormScreen';
import { SupplierDetailScreen } from '@/features/suppliers/SupplierDetailScreen';
import { SupplierStatementScreen } from '@/features/suppliers/SupplierStatementScreen';
import { ChequeRegisterScreen } from '@/features/payments/ChequeRegisterScreen';
import { PaymentDetailScreen } from '@/features/payments/PaymentDetailScreen';
import { PaymentFormScreen } from '@/features/payments/PaymentFormScreen';
import { CustomersScreen } from '@/features/customers/CustomersScreen';
import { CustomerFormScreen } from '@/features/customers/CustomerFormScreen';
import { MoreScreen } from '@/features/settings/MoreScreen';
import { FiscalYearFormScreen } from '@/features/settings/FiscalYearFormScreen';
import { ShopFormScreen } from '@/features/settings/ShopFormScreen';
import { NotFoundScreen } from '@/features/NotFoundScreen';

/**
 * One flat route table under the shell. Nothing is lazy-loaded: the whole app
 * is a couple of hundred kilobytes, and splitting it would buy a spinner per
 * navigation for no measurable gain on a phone.
 *
 * `/new` routes are declared before `/:id` so "new" is never read as an id.
 *
 * `/login` sits inside the shell but outside the auth gate — it renders in the
 * same phone frame as everything else, and it is the one screen that must work
 * without a session.
 */
export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    errorElement: <NotFoundScreen />,
    children: [
      { path: 'login', element: <LoginScreen /> },

      {
        // Pathless layout route: everything below it needs a signed-in user.
        element: <RequireAuth />,
        children: [
          { index: true, element: <DashboardScreen /> },

          { path: 'purchases', element: <PurchasesScreen /> },
          { path: 'purchases/new', element: <PurchaseFormScreen /> },
          { path: 'purchases/:id', element: <PurchaseDetailScreen /> },

          { path: 'sales', element: <SalesScreen /> },
          { path: 'sales/new', element: <SaleFormScreen /> },
          { path: 'sales/day/:date', element: <SaleDayScreen /> },
          { path: 'sales/:id', element: <SaleDetailScreen /> },

          { path: 'suppliers', element: <SuppliersScreen /> },
          { path: 'suppliers/new', element: <SupplierFormScreen /> },
          { path: 'suppliers/:id', element: <SupplierDetailScreen /> },
          { path: 'suppliers/:id/statement', element: <SupplierStatementScreen /> },

          { path: 'cheques', element: <ChequeRegisterScreen /> },
          { path: 'payments/new', element: <PaymentFormScreen /> },
          { path: 'payments/:id', element: <PaymentDetailScreen /> },

          { path: 'customers', element: <CustomersScreen /> },
          { path: 'customers/new', element: <CustomerFormScreen /> },

          { path: 'more', element: <MoreScreen /> },
          { path: 'shop', element: <ShopFormScreen /> },
          { path: 'fiscal-years/new', element: <FiscalYearFormScreen /> },

          { path: '*', element: <NotFoundScreen /> },
        ],
      },
    ],
  },
]);
