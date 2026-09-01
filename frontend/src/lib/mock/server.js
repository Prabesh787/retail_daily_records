/**
 * Mock transport. Implements the same routes as the Express API against the
 * fixtures in `data.js`, with the same success envelope, the same pagination
 * meta and a small artificial latency so loading states are actually visible.
 *
 * It exists so the interface can be built, reviewed and demonstrated without a
 * database — and because several write endpoints on the backend are still
 * `501 Not Implemented`. Nothing outside this folder knows it exists: the
 * signature matches `httpRequest` exactly.
 */

import { ApiError } from '../api/http.js';
import { adToBs } from './bs-calendar.js';
import { PAGE_SIZE } from '../constants.js';
import {
  attachments,
  currentUser,
  customers,
  fiscalYears,
  purchases,
  sales,
  supplierPayments,
  suppliers,
} from './data.js';

const LATENCY_MS = 260;

const delay = (ms = LATENCY_MS) => new Promise((resolve) => setTimeout(resolve, ms));

const num = (value) => Number(value ?? 0);
const money = (value) => value.toFixed(2);
const sum = (list, key) => list.reduce((total, row) => total + num(row[key]), 0);

let sequence = 9000;
const nextId = (prefix) => `${prefix}-${(sequence += 1)}`;

/* --- Shared helpers ------------------------------------------------------- */

function paginate(rows, params = {}) {
  const page = Math.max(1, Number(params.page) || 1);
  const limit = Math.min(100, Number(params.limit) || PAGE_SIZE);
  const start = (page - 1) * limit;
  return {
    data: rows.slice(start, start + limit),
    meta: {
      page,
      limit,
      total: rows.length,
      totalPages: Math.max(1, Math.ceil(rows.length / limit)),
    },
  };
}

function matchesSearch(haystacks, term) {
  if (!term) return true;
  const needle = String(term).toLowerCase();
  return haystacks.filter(Boolean).some((value) => String(value).toLowerCase().includes(needle));
}

function inRange(date, from, to) {
  if (from && date < from) return false;
  if (to && date > to) return false;
  return true;
}

const supplierById = (id) => suppliers.find((row) => row.id === id) ?? null;
const customerById = (id) => customers.find((row) => row.id === id) ?? null;

/** The list rows every screen shows: the record plus the names it points at. */
const expandPurchase = (purchase) => ({
  ...purchase,
  supplier: supplierById(purchase.supplierId),
});

const expandPayment = (payment) => ({
  ...payment,
  supplier: supplierById(payment.supplierId),
  purchase: purchases.find((row) => row.id === payment.purchaseId) ?? null,
});

const expandSale = (sale) => ({
  ...sale,
  customer: customerById(sale.customerId),
});

/**
 * The one calculation the whole system is built around: what the shop still
 * owes a supplier. Derived from the transactions every time, never stored.
 *
 *   opening balance + purchases − payments that are not cancelled
 */
function supplierBalance(supplierId) {
  const bills = purchases.filter((row) => row.supplierId === supplierId);
  const payments = supplierPayments.filter(
    (row) => row.supplierId === supplierId && row.status !== 'CANCELLED',
  );
  const supplier = supplierById(supplierId);

  const purchased = sum(bills, 'amount');
  const cleared = sum(
    payments.filter((row) => row.status === 'CLEARED'),
    'amount',
  );
  const issued = sum(
    payments.filter((row) => row.status === 'ISSUED'),
    'amount',
  );
  const opening = num(supplier?.openingBalance);

  return {
    openingBalance: money(opening),
    purchaseTotal: money(purchased),
    paidTotal: money(cleared + issued),
    clearedTotal: money(cleared),
    /** Cheques handed over but not yet debited — promised, not gone. */
    unclearedTotal: money(issued),
    outstanding: money(opening + purchased - cleared - issued),
    billCount: bills.length,
    paymentCount: payments.length,
  };
}

/**
 * A statement for one date window. `openingAsOf` is the position carried into
 * `from` — the supplier's opening balance plus every movement before that date
 * — so the closing figure below still reconciles with the all-time balance.
 */
function supplierWindow(supplierId, from, to) {
  const supplier = supplierById(supplierId);
  const bills = purchases.filter((row) => row.supplierId === supplierId);
  const payments = supplierPayments.filter(
    (row) => row.supplierId === supplierId && row.status !== 'CANCELLED',
  );

  const before = (date, boundary) => Boolean(boundary) && date < boundary;

  const openingAsOf =
    num(supplier?.openingBalance) +
    sum(
      bills.filter((row) => before(row.billDate, from)),
      'amount',
    ) -
    sum(
      payments.filter((row) => before(row.paymentDate, from)),
      'amount',
    );

  const windowBills = bills.filter((row) => inRange(row.billDate, from, to));
  const windowPayments = payments.filter((row) => inRange(row.paymentDate, from, to));

  const purchaseTotal = sum(windowBills, 'amount');
  const paymentTotal = sum(windowPayments, 'amount');

  return {
    from: from ?? null,
    to: to ?? null,
    openingAsOf: money(openingAsOf),
    purchaseTotal: money(purchaseTotal),
    paymentTotal: money(paymentTotal),
    clearedTotal: money(
      sum(
        windowPayments.filter((r) => r.status === 'CLEARED'),
        'amount',
      ),
    ),
    unclearedTotal: money(
      sum(
        windowPayments.filter((r) => r.status === 'ISSUED'),
        'amount',
      ),
    ),
    closing: money(openingAsOf + purchaseTotal - paymentTotal),
    billCount: windowBills.length,
    paymentCount: windowPayments.length,
  };
}

/* --- Route table ---------------------------------------------------------- */

const routes = [
  ['GET', /^\/health$/, () => ({ status: 'ok', mode: 'mock' })],

  ['GET', /^\/auth\/me$/, () => ({ user: currentUser, shop: currentUser.shop })],
  [
    'PATCH',
    /^\/auth\/me$/,
    (_m, _params, body = {}) => {
      // Mirrors the API's rules exactly: a key that is not sent is left alone,
      // and a key sent empty is cleared to null. Anything else — role, email,
      // isActive — is simply not a field this endpoint reads.
      const clean = (value) => {
        const text = typeof value === 'string' ? value.trim() : '';
        return text === '' ? null : text;
      };

      if ('name' in body && clean(body.name)) currentUser.name = clean(body.name);
      for (const [sent, field] of [
        ['shopName', 'name'],
        ['shopAddress', 'address'],
        ['shopPhone', 'phone'],
        ['shopPan', 'pan'],
      ]) {
        if (sent in body) currentUser.shop[field] = clean(body[sent]);
      }

      return { user: currentUser, shop: currentUser.shop };
    },
  ],
  [
    'POST',
    /^\/auth\/login$/,
    (_m, _params, body) => {
      // Any password is accepted here on purpose: this transport exists so the
      // interface can be driven without a backend, and it has no password
      // hashes to check against. The real check lives in the Express API.
      if (!body?.email) {
        throw new ApiError('The email or password is incorrect.', {
          status: 401,
          code: 'UNAUTHORIZED',
        });
      }
      return {
        token: `mock.${Date.now()}`,
        tokenType: 'Bearer',
        expiresIn: '1d',
        user: { ...currentUser, email: body.email },
        shop: currentUser.shop,
      };
    },
  ],

  ['GET', /^\/fiscal-years$/, () => fiscalYears],
  ['GET', /^\/fiscal-years\/active$/, () => fiscalYears.find((fy) => fy.isActive)],
  [
    'POST',
    /^\/fiscal-years$/,
    (_m, _params, body) => {
      const year = { id: nextId('fy'), startDateBs: null, endDateBs: null, ...body };
      // Exactly one year is active at a time, here as on the server.
      if (year.isActive) fiscalYears.forEach((row) => (row.isActive = false));
      fiscalYears.unshift(year);
      return year;
    },
  ],
  [
    'POST',
    /^\/fiscal-years\/([\w-]+)\/activate$/,
    ([id]) => {
      const year = fiscalYears.find((row) => row.id === id);
      if (!year) throw new ApiError('Fiscal year not found', { status: 404, code: 'NOT_FOUND' });
      fiscalYears.forEach((row) => (row.isActive = row.id === id));
      return year;
    },
  ],

  /* --- Suppliers ---------------------------------------------------------- */
  [
    'GET',
    /^\/suppliers$/,
    (_m, params) => {
      let rows = suppliers.filter((row) =>
        matchesSearch([row.name, row.phone, row.contactPerson], params.q),
      );
      if (params.isActive !== undefined) {
        rows = rows.filter((row) => String(row.isActive) === String(params.isActive));
      }
      rows = rows
        .map((row) => ({ ...row, balance: supplierBalance(row.id) }))
        .sort((a, b) => num(b.balance.outstanding) - num(a.balance.outstanding));
      return paginate(rows, params);
    },
  ],
  [
    'GET',
    /^\/suppliers\/([\w-]+)$/,
    ([id], params) => {
      const supplier = supplierById(id);
      if (!supplier) throw new ApiError('Supplier not found', { status: 404, code: 'NOT_FOUND' });

      const { from, to, q } = params;

      const bills = purchases
        .filter((row) => row.supplierId === id)
        .filter((row) => inRange(row.billDate, from, to))
        .filter((row) => matchesSearch([row.billNo, row.description, row.remarks], q));

      const paid = supplierPayments
        .filter((row) => row.supplierId === id)
        .filter((row) => inRange(row.paymentDate, from, to))
        .filter((row) =>
          matchesSearch(
            [
              row.voucherNo,
              row.chequeNo,
              row.referenceNo,
              row.description,
              // A payment is searchable by the bill it settles.
              purchases.find((bill) => bill.id === row.purchaseId)?.billNo,
            ],
            q,
          ),
        );

      return {
        ...supplier,
        balance: supplierBalance(id),
        window: supplierWindow(id, from, to),
        purchases: bills.map((row) => ({ ...row, supplier })),
        payments: paid.map(expandPayment),
      };
    },
  ],
  [
    'POST',
    /^\/suppliers$/,
    (_m, _params, body) => {
      const supplier = {
        id: nextId('sup'),
        isActive: true,
        openingBalance: money(num(body.openingBalance)),
        email: null,
        remarks: null,
        ...body,
        createdAt: new Date().toISOString(),
      };
      suppliers.unshift(supplier);
      return supplier;
    },
  ],

  /* --- Customers ---------------------------------------------------------- */
  [
    'GET',
    /^\/customers$/,
    (_m, params) => {
      const rows = customers
        .filter((row) => matchesSearch([row.name, row.phone, row.address], params.q))
        .map((row) => {
          const own = sales.filter((sale) => sale.customerId === row.id);
          return { ...row, saleCount: own.length, saleTotal: money(sum(own, 'totalAmount')) };
        });
      return paginate(rows, params);
    },
  ],
  [
    'GET',
    /^\/customers\/([\w-]+)$/,
    ([id]) => {
      const customer = customerById(id);
      if (!customer) throw new ApiError('Customer not found', { status: 404, code: 'NOT_FOUND' });
      const own = sales.filter((sale) => sale.customerId === id);
      return {
        ...customer,
        saleCount: own.length,
        saleTotal: money(sum(own, 'totalAmount')),
        sales: own.slice(0, 30).map(expandSale),
      };
    },
  ],
  [
    'POST',
    /^\/customers$/,
    (_m, _params, body) => {
      const customer = { id: nextId('cus'), ...body, createdAt: new Date().toISOString() };
      customers.unshift(customer);
      return customer;
    },
  ],

  /* --- Purchases ---------------------------------------------------------- */
  [
    'GET',
    /^\/purchases$/,
    (_m, params) => {
      const rows = purchases
        .filter((row) => !params.supplierId || row.supplierId === params.supplierId)
        .filter((row) => !params.fiscalYearId || row.fiscalYearId === params.fiscalYearId)
        .filter((row) => inRange(row.billDate, params.from, params.to))
        .filter((row) =>
          matchesSearch(
            [row.billNo, row.description, supplierById(row.supplierId)?.name],
            params.q,
          ),
        )
        .map(expandPurchase);
      return paginate(rows, params);
    },
  ],
  [
    'GET',
    /^\/purchases\/([\w-]+)$/,
    ([id]) => {
      const purchase = purchases.find((row) => row.id === id);
      if (!purchase) throw new ApiError('Purchase not found', { status: 404, code: 'NOT_FOUND' });
      const paid = supplierPayments.filter(
        (row) => row.purchaseId === id && row.status !== 'CANCELLED',
      );
      return {
        ...expandPurchase(purchase),
        payments: paid,
        paidTotal: money(sum(paid, 'amount')),
        dueTotal: money(num(purchase.amount) - sum(paid, 'amount')),
        attachments: attachments.filter(
          (row) => row.entityType === 'PURCHASE' && row.entityId === id,
        ),
      };
    },
  ],
  [
    'POST',
    /^\/purchases$/,
    (_m, _params, body) => {
      const purchase = {
        id: nextId('pur'),
        fiscalYearId: body.fiscalYearId ?? fiscalYears.find((fy) => fy.isActive).id,
        remarks: null,
        description: null,
        ...body,
        amount: money(num(body.amount)),
        createdAt: new Date().toISOString(),
      };
      purchases.unshift(purchase);
      return expandPurchase(purchase);
    },
  ],

  /* --- Supplier payments -------------------------------------------------- */
  [
    'GET',
    /^\/supplier-payments\/cheque-register$/,
    (_m, params) => {
      const rows = supplierPayments
        .filter((row) => row.paymentMode === 'CHEQUE')
        .filter((row) => !params.status || row.status === params.status)
        .filter((row) => inRange(row.chequeDate, params.from, params.to))
        // Ordered by the date written on the cheque: the order the money has
        // to be in the account.
        .sort((a, b) => a.chequeDate.localeCompare(b.chequeDate))
        .map(expandPayment);
      return paginate(rows, { ...params, limit: params.limit ?? 100 });
    },
  ],
  [
    'GET',
    /^\/supplier-payments$/,
    (_m, params) => {
      const rows = supplierPayments
        .filter((row) => !params.supplierId || row.supplierId === params.supplierId)
        .filter((row) => !params.status || row.status === params.status)
        .filter((row) => !params.paymentMode || row.paymentMode === params.paymentMode)
        .filter((row) => inRange(row.paymentDate, params.from, params.to))
        .filter((row) =>
          matchesSearch(
            [row.voucherNo, row.chequeNo, row.referenceNo, supplierById(row.supplierId)?.name],
            params.q,
          ),
        )
        .map(expandPayment);
      return paginate(rows, params);
    },
  ],
  [
    'GET',
    /^\/supplier-payments\/([\w-]+)$/,
    ([id]) => {
      const payment = supplierPayments.find((row) => row.id === id);
      if (!payment) throw new ApiError('Payment not found', { status: 404, code: 'NOT_FOUND' });
      return expandPayment(payment);
    },
  ],
  [
    'POST',
    /^\/supplier-payments$/,
    (_m, _params, body) => {
      const payment = {
        id: nextId('spy'),
        fiscalYearId: body.fiscalYearId ?? fiscalYears.find((fy) => fy.isActive).id,
        purchaseId: null,
        chequeNo: null,
        chequeDate: null,
        referenceNo: null,
        clearedDate: null,
        ...body,
        amount: money(num(body.amount)),
        // Cash is money already gone; a cheque is only a promise until it clears.
        status: body.status ?? (body.paymentMode === 'CHEQUE' ? 'ISSUED' : 'CLEARED'),
        createdAt: new Date().toISOString(),
      };
      if (payment.status === 'CLEARED' && !payment.clearedDate) {
        payment.clearedDate = payment.paymentDate;
      }
      supplierPayments.unshift(payment);
      return expandPayment(payment);
    },
  ],
  [
    'POST',
    /^\/supplier-payments\/([\w-]+)\/clear$/,
    ([id], _params, body) => {
      const payment = supplierPayments.find((row) => row.id === id);
      if (!payment) throw new ApiError('Payment not found', { status: 404, code: 'NOT_FOUND' });
      if (payment.status === 'CANCELLED') {
        throw new ApiError('A cancelled cheque cannot be cleared', {
          status: 400,
          code: 'BUSINESS_RULE_VIOLATION',
        });
      }
      payment.status = 'CLEARED';
      payment.clearedDate = body?.clearedDate ?? new Date().toISOString().slice(0, 10);
      return expandPayment(payment);
    },
  ],
  [
    'POST',
    /^\/supplier-payments\/([\w-]+)\/cancel$/,
    ([id]) => {
      const payment = supplierPayments.find((row) => row.id === id);
      if (!payment) throw new ApiError('Payment not found', { status: 404, code: 'NOT_FOUND' });
      payment.status = 'CANCELLED';
      payment.clearedDate = null;
      return expandPayment(payment);
    },
  ],

  /* --- Sales -------------------------------------------------------------- */
  [
    'GET',
    /^\/sales\/day-book$/,
    (_m, params) => {
      const date = params.date ?? new Date().toISOString().slice(0, 10);
      const daySales = sales.filter((row) => row.saleDate === date);
      const dayPurchases = purchases.filter((row) => row.billDate === date);
      const dayPayments = supplierPayments.filter((row) => row.paymentDate === date);
      // What came in, split by how it was settled. CREDIT is money not yet
      // received, so it is reported apart from the rest.
      const byMode = {};
      for (const sale of daySales) {
        for (const payment of sale.payments ?? []) {
          byMode[payment.paymentMode] = (byMode[payment.paymentMode] ?? 0) + num(payment.amount);
        }
      }

      return {
        date,
        dateBs: adToBs(date),
        sales: daySales.map(expandSale),
        purchases: dayPurchases.map(expandPurchase),
        payments: dayPayments.map(expandPayment),
        totals: {
          sales: money(sum(daySales, 'totalAmount')),
          saleCount: daySales.length,
          purchases: money(sum(dayPurchases, 'amount')),
          payments: money(sum(dayPayments, 'amount')),
          byMode: Object.fromEntries(
            Object.entries(byMode).map(([mode, value]) => [mode, money(value)]),
          ),
        },
      };
    },
  ],
  [
    'GET',
    /^\/sales$/,
    (_m, params) => {
      const rows = sales
        .filter((row) => !params.saleType || row.saleType === params.saleType)
        .filter((row) => !params.customerId || row.customerId === params.customerId)
        .filter((row) => !params.fiscalYearId || row.fiscalYearId === params.fiscalYearId)
        .filter((row) => inRange(row.saleDate, params.from, params.to))
        .filter((row) =>
          matchesSearch(
            [row.invoiceNo, row.description, customerById(row.customerId)?.name],
            params.q,
          ),
        )
        .map(expandSale);
      return paginate(rows, params);
    },
  ],
  [
    'GET',
    /^\/sales\/([\w-]+)$/,
    ([id]) => {
      const sale = sales.find((row) => row.id === id);
      if (!sale) throw new ApiError('Sale not found', { status: 404, code: 'NOT_FOUND' });
      return expandSale(sale);
    },
  ],
  [
    'POST',
    /^\/sales$/,
    (_m, _params, body) => {
      const items = (body.items ?? []).map((item) => ({
        id: nextId('sit'),
        ...item,
        // Line amounts are recomputed, never taken from the client.
        amount: money(num(item.quantity) * num(item.unitPrice) - num(item.discount)),
      }));
      const subtotal = items.length ? sum(items, 'amount') : num(body.totalAmount);
      const discount = num(body.discount);

      const sale = {
        id: nextId('sal'),
        fiscalYearId: body.fiscalYearId ?? fiscalYears.find((fy) => fy.isActive).id,
        invoiceNo: null,
        customerId: null,
        description: null,
        remarks: null,
        ...body,
        items,
        payments: (body.payments ?? []).map((payment) => ({ id: nextId('spm'), ...payment })),
        subtotal: money(subtotal),
        discount: money(discount),
        totalAmount: money(subtotal - discount),
        createdAt: new Date().toISOString(),
      };
      sales.unshift(sale);
      return expandSale(sale);
    },
  ],

  /* --- Reports ------------------------------------------------------------ */
  [
    'GET',
    /^\/reports\/dashboard$/,
    (_m, params) => {
      const today = new Date().toISOString().slice(0, 10);
      const windowStart =
        params.from ?? new Date(Date.now() - 29 * 86400000).toISOString().slice(0, 10);

      const salesToday = sales.filter((row) => row.saleDate === today);
      const salesWindow = sales.filter((row) => inRange(row.saleDate, windowStart, today));
      const purchasesWindow = purchases.filter((row) => inRange(row.billDate, windowStart, today));

      const outstanding = suppliers
        .map((supplier) => ({ supplier, balance: supplierBalance(supplier.id) }))
        .filter((row) => num(row.balance.outstanding) > 0)
        .sort((a, b) => num(b.balance.outstanding) - num(a.balance.outstanding));

      const upcomingCheques = supplierPayments
        .filter((row) => row.status === 'ISSUED' && row.paymentMode === 'CHEQUE')
        .sort((a, b) => a.chequeDate.localeCompare(b.chequeDate))
        .map(expandPayment);

      // Sales per day for the sparkline, oldest first.
      const trend = [];
      for (let i = 13; i >= 0; i -= 1) {
        const date = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
        trend.push({
          date,
          amount: money(
            sum(
              sales.filter((row) => row.saleDate === date),
              'totalAmount',
            ),
          ),
        });
      }

      return {
        today: {
          date: today,
          dateBs: adToBs(today),
          salesTotal: money(sum(salesToday, 'totalAmount')),
          salesCount: salesToday.length,
        },
        window: {
          from: windowStart,
          to: today,
          salesTotal: money(sum(salesWindow, 'totalAmount')),
          purchaseTotal: money(sum(purchasesWindow, 'amount')),
        },
        payable: {
          total: money(outstanding.reduce((acc, row) => acc + num(row.balance.outstanding), 0)),
          supplierCount: outstanding.length,
          top: outstanding.slice(0, 4),
        },
        cheques: {
          count: upcomingCheques.length,
          total: money(sum(upcomingCheques, 'amount')),
          next: upcomingCheques.slice(0, 3),
        },
        trend,
        recentSales: sales.slice(0, 4).map(expandSale),
        recentPurchases: purchases.slice(0, 4).map(expandPurchase),
      };
    },
  ],
  [
    'GET',
    /^\/reports\/supplier-outstanding$/,
    () =>
      suppliers
        .map((supplier) => ({ ...supplier, balance: supplierBalance(supplier.id) }))
        .sort((a, b) => num(b.balance.outstanding) - num(a.balance.outstanding)),
  ],
];

/* --- Entry point ---------------------------------------------------------- */

export async function mockRequest(path, { method = 'GET', params = {}, body } = {}) {
  await delay();

  for (const [routeMethod, pattern, handler] of routes) {
    if (routeMethod !== method) continue;
    const match = pattern.exec(path);
    if (!match) continue;

    const result = handler(match.slice(1), params, body);
    // A handler either returns a page (`{ data, meta }`) or a bare payload.
    if (result && typeof result === 'object' && 'data' in result && 'meta' in result) return result;
    return { data: result ?? null };
  }

  throw new ApiError(`No mock handler for ${method} ${path}`, { status: 404, code: 'NOT_FOUND' });
}
