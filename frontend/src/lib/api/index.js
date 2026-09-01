/**
 * The single door every feature goes through to reach data.
 *
 * `VITE_API_MODE=mock` swaps the transport for in-memory fixtures. Feature code
 * never branches on the mode — it calls `api.purchases.list(...)` either way.
 *
 * Every endpoint here is implemented on the backend, and every one of them
 * except `/auth/login` and `/health` requires a bearer token; `http.js` attaches
 * it, so nothing below has to think about authentication.
 */

import { httpRequest } from './http.js';
import { mockRequest } from '../mock/server.js';
import { clearToken, setToken } from './auth-token.js';

export const API_MODE = import.meta.env.VITE_API_MODE === 'live' ? 'live' : 'mock';

const request = API_MODE === 'live' ? httpRequest : mockRequest;

/** Unwraps to the payload alone, for calls that are not paged. */
const one = async (...args) => (await request(...args)).data;

export const api = {
  mode: API_MODE,

  health: () => one('/health'),
  me: () => one('/auth/me'),
  /**
   * The signed-in account editing itself: display name and shop details. Only
   * the keys sent are written, so the shop form can leave `name` alone.
   */
  updateMe: (body) => one('/auth/me', { method: 'PATCH', body }),

  auth: {
    /** Stores the token as a side effect: nothing else should have to. */
    async login(body) {
      const session = await one('/auth/login', { method: 'POST', body });
      if (session?.token) setToken(session.token);
      return session;
    },
    /** There is no server-side session to end - dropping the token is the act. */
    logout: () => clearToken(),
  },

  fiscalYears: {
    list: () => one('/fiscal-years'),
    active: () => one('/fiscal-years/active'),
    create: (body) => one('/fiscal-years', { method: 'POST', body }),
    activate: (id) => one(`/fiscal-years/${id}/activate`, { method: 'POST' }),
  },

  suppliers: {
    list: (params) => request('/suppliers', { params }),
    /** `params` narrows the ledger to a date window: { from, to, q }. */
    get: (id, params) => one(`/suppliers/${id}`, { params }),
    create: (body) => one('/suppliers', { method: 'POST', body }),
    update: (id, body) => one(`/suppliers/${id}`, { method: 'PATCH', body }),
  },

  customers: {
    list: (params) => request('/customers', { params }),
    get: (id) => one(`/customers/${id}`),
    create: (body) => one('/customers', { method: 'POST', body }),
    update: (id, body) => one(`/customers/${id}`, { method: 'PATCH', body }),
  },

  purchases: {
    list: (params) => request('/purchases', { params }),
    get: (id) => one(`/purchases/${id}`),
    create: (body) => one('/purchases', { method: 'POST', body }),
  },

  supplierPayments: {
    list: (params) => request('/supplier-payments', { params }),
    chequeRegister: (params) => request('/supplier-payments/cheque-register', { params }),
    get: (id) => one(`/supplier-payments/${id}`),
    create: (body) => one('/supplier-payments', { method: 'POST', body }),
    clear: (id, body) => one(`/supplier-payments/${id}/clear`, { method: 'POST', body }),
    cancel: (id) => one(`/supplier-payments/${id}/cancel`, { method: 'POST' }),
  },

  sales: {
    list: (params) => request('/sales', { params }),
    get: (id) => one(`/sales/${id}`),
    create: (body) => one('/sales', { method: 'POST', body }),
    dayBook: (date) => one('/sales/day-book', { params: { date } }),
  },

  reports: {
    dashboard: (params) => one('/reports/dashboard', { params }),
    supplierOutstanding: () => one('/reports/supplier-outstanding'),
  },
};

export { ApiError } from './http.js';
export { getToken, clearToken, AUTH_EXPIRED_EVENT } from './auth-token.js';
