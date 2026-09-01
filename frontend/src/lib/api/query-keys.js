/**
 * Every React Query cache key in one place, so an invalidation after a mutation
 * cannot miss a list that is showing the same data.
 */
export const queryKeys = {
  me: ['me'],
  fiscalYears: ['fiscal-years'],
  dashboard: (params) => ['dashboard', params ?? {}],

  suppliers: (params) => ['suppliers', params ?? {}],
  supplier: (id, params) => ['supplier', id, params ?? {}],

  customers: (params) => ['customers', params ?? {}],
  customer: (id) => ['customer', id],

  purchases: (params) => ['purchases', params ?? {}],
  purchase: (id) => ['purchase', id],

  payments: (params) => ['supplier-payments', params ?? {}],
  payment: (id) => ['supplier-payment', id],
  chequeRegister: (params) => ['cheque-register', params ?? {}],

  sales: (params) => ['sales', params ?? {}],
  dayBook: (date) => ['day-book', date],
  sale: (id) => ['sale', id],
};
