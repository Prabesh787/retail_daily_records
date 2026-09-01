/**
 * In-memory fixtures for `VITE_API_MODE=mock`.
 *
 * Shapes match the Prisma models exactly — decimals are strings, dates are
 * ISO `YYYY-MM-DD`, every BS date sits beside its AD twin — so switching to
 * the live API changes the transport and nothing else.
 */

import { adToBs } from './bs-calendar.js';

/* --- Deterministic randomness so every reload shows the same shop ---------- */
let seed = 20830516;
function rand() {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return seed / 2147483648;
}
const pick = (list) => list[Math.floor(rand() * list.length)];
const between = (min, max) => min + Math.floor(rand() * (max - min + 1));
const money = (value) => value.toFixed(2);

const TODAY = new Date();
const iso = (date) => date.toISOString().slice(0, 10);
const daysAgo = (n) => iso(new Date(TODAY.getTime() - n * 86400000));
const daysAhead = (n) => iso(new Date(TODAY.getTime() + n * 86400000));

let counter = 0;
const uid = (prefix) => `${prefix}-${String((counter += 1)).padStart(4, '0')}`;

/* --- Users ---------------------------------------------------------------- */

/**
 * The shop hangs off the user, exactly as it does on the API's `users` row —
 * it is editable from More > Shop details rather than fixed in configuration,
 * so the mock keeps it mutable and the PATCH handler writes through to it.
 */
export const currentUser = {
  id: 'user-0001',
  name: 'Prabesh Bhattarai',
  email: 'shop@retailrecords.np',
  role: 'ADMIN',
  isActive: true,
  shop: {
    name: 'Namuna Cloth House',
    address: 'Butwal-11, Rupandehi',
    phone: null,
    pan: '301234567',
  },
};

/* --- Fiscal years --------------------------------------------------------- */

export const fiscalYears = [
  {
    id: 'fy-2083-84',
    name: '2083/84',
    startDate: '2026-07-17',
    endDate: '2027-07-16',
    startDateBs: '2083-04-01',
    endDateBs: '2084-03-31',
    isActive: true,
  },
  {
    id: 'fy-2082-83',
    name: '2082/83',
    startDate: '2025-07-17',
    endDate: '2026-07-16',
    startDateBs: '2082-04-01',
    endDateBs: '2083-03-32',
    isActive: false,
  },
];

const ACTIVE_FY = fiscalYears[0].id;

/* --- Suppliers ------------------------------------------------------------ */

const supplierSeeds = [
  ['ABC Textile Udhyog', 'Ramesh Agrawal', '9801234567', 'Birgunj, Parsa', 125000],
  ['Shree Krishna Fabrics', 'Sita Sharma', '9847112233', 'New Road, Kathmandu', 0],
  ['Everest Garments Pvt. Ltd.', 'Binod Thapa', '9856004411', 'Balkumari, Lalitpur', 48500],
  ['Himalayan Cotton Mills', 'Anita Gurung', '9812778899', 'Biratnagar, Morang', 0],
  ['Pashupati Suiting House', 'Gopal Shrestha', '9741556677', 'Bhairahawa, Rupandehi', 32000],
  ['Nepal Readymade Depot', 'Kiran Maharjan', '9808991122', 'Pokhara-8, Kaski', 0],
  ['Lumbini Hosiery Center', 'Dipak Yadav', '9857033445', 'Butwal-9, Rupandehi', 15750],
  ['Sunrise Woollens', 'Manisha Rai', '9803667788', 'Itahari, Sunsari', 0],
];

export const suppliers = supplierSeeds.map(
  ([name, contactPerson, phone, address, openingBalance], index) => ({
    id: `sup-${String(index + 1).padStart(4, '0')}`,
    name,
    contactPerson,
    phone,
    email: null,
    address,
    pan: String(600000000 + index * 137),
    openingBalance: money(openingBalance),
    isActive: index !== 7,
    remarks: null,
    createdAt: `${daysAgo(400 - index * 9)}T04:00:00.000Z`,
  }),
);

/* --- Customers ------------------------------------------------------------ */

const customerSeeds = [
  ['Sunita Poudel', '9841223344', 'Butwal-11'],
  ['Hari Bahadur Thapa', '9857112200', 'Devinagar'],
  ['Kalika Boutique', '9807445566', 'Traffic Chowk, Butwal'],
  ['Rajesh Gupta', '9812009988', 'Bhairahawa'],
  ['Nirmala Tailors', '9749887766', 'Milanchowk'],
  ['Bishnu Adhikari', '9866554433', 'Tilottama-4'],
  ['Sharma Uniform Supply', '9801778899', 'Butwal-13'],
  ['Manju Karki', '9843221100', 'Golpark'],
];

export const customers = customerSeeds.map(([name, phone, address], index) => ({
  id: `cus-${String(index + 1).padStart(4, '0')}`,
  name,
  phone,
  address,
  pan: index % 3 === 0 ? String(500000000 + index * 211) : null,
  remarks: null,
  createdAt: `${daysAgo(300 - index * 12)}T04:00:00.000Z`,
}));

/* --- Purchases ------------------------------------------------------------ */

const PURCHASE_DESCRIPTIONS = [
  'Cotton shirting - assorted colours',
  'Ladies kurtha sets - festive stock',
  'Denim jeans - 40 pcs mixed sizes',
  'School uniform fabric - navy',
  'Woollen shawls and mufflers',
  'Printed cotton sarees',
  'Kids readymade - winter range',
  'Suiting and shirting bundle',
  'Bedsheets and pillow covers',
  'Hosiery - vests and socks',
];

export const purchases = [];

for (let i = 0; i < 42; i += 1) {
  const supplier = suppliers[between(0, suppliers.length - 2)];
  const offset = between(0, 150);
  const billDate = daysAgo(offset);
  purchases.push({
    id: uid('pur'),
    fiscalYearId: offset > 46 ? 'fy-2082-83' : ACTIVE_FY,
    supplierId: supplier.id,
    billNo: String(between(1000, 9999)),
    billDate,
    billDateBs: adToBs(billDate),
    description: pick(PURCHASE_DESCRIPTIONS),
    amount: money(between(12, 320) * 1000 + between(0, 99) * 10),
    remarks: null,
    createdAt: `${billDate}T05:30:00.000Z`,
  });
}

purchases.sort((a, b) => b.billDate.localeCompare(a.billDate));

/* --- Supplier payments ---------------------------------------------------- */

export const supplierPayments = [];

for (const purchase of purchases) {
  const roll = rand();
  // Roughly a fifth of bills are still fully open credit.
  if (roll < 0.2) continue;

  const total = Number(purchase.amount);
  const parts = roll < 0.55 ? 1 : 2;
  let remaining = roll < 0.45 ? total : total * (0.4 + rand() * 0.5);

  for (let p = 0; p < parts; p += 1) {
    const isLast = p === parts - 1;
    const amount = isLast ? remaining : Math.round((remaining * 0.5) / 100) * 100;
    remaining -= amount;
    if (amount < 500) continue;

    const mode = pick(['CASH', 'CASH', 'CHEQUE', 'CHEQUE', 'BANK_TRANSFER']);
    const paymentDate = daysAgo(Math.max(0, between(0, 20) + daysSince(purchase.billDate) - 20));

    /** A cheque may still be sitting with the supplier, undated in the bank. */
    const future = mode === 'CHEQUE' && rand() < 0.45;
    const chequeDate = future ? daysAhead(between(2, 26)) : paymentDate;
    const status = mode === 'CHEQUE' ? (future ? 'ISSUED' : 'CLEARED') : 'CLEARED';

    supplierPayments.push({
      id: uid('spy'),
      fiscalYearId: purchase.fiscalYearId,
      supplierId: purchase.supplierId,
      purchaseId: purchase.id,
      voucherNo: `V-${String(supplierPayments.length + 1).padStart(4, '0')}`,
      paymentDate,
      paymentDateBs: adToBs(paymentDate),
      paymentMode: mode,
      amount: money(Math.round(amount)),
      chequeNo: mode === 'CHEQUE' ? String(between(100000, 999999)) : null,
      chequeDate: mode === 'CHEQUE' ? chequeDate : null,
      chequeDateBs: mode === 'CHEQUE' ? adToBs(chequeDate) : null,
      referenceNo: mode === 'BANK_TRANSFER' ? `TXN${between(10000000, 99999999)}` : null,
      clearedDate: status === 'CLEARED' ? paymentDate : null,
      status,
      description: `Against bill ${purchase.billNo}`,
      remarks: null,
      createdAt: `${paymentDate}T06:00:00.000Z`,
    });
  }
}

function daysSince(isoDate) {
  return Math.round(
    (Date.parse(`${iso(TODAY)}T00:00:00Z`) - Date.parse(`${isoDate}T00:00:00Z`)) / 86400000,
  );
}

supplierPayments.sort((a, b) => b.paymentDate.localeCompare(a.paymentDate));

/* --- Sales ---------------------------------------------------------------- */

const ITEM_DESCRIPTIONS = [
  ['Printed cotton - blue', 'METER', 780],
  ['Ladies kurtha set', 'SET', 2450],
  ['Mens formal shirt', 'PCS', 1350],
  ['School trouser - navy', 'PCS', 950],
  ['Woollen shawl', 'PCS', 1850],
  ['Cotton bedsheet - double', 'SET', 2100],
  ['Kids t-shirt', 'PCS', 620],
  ['Silk saree - banarasi', 'PCS', 8500],
  ['Denim jeans', 'PCS', 2250],
  ['Socks - pack of 3', 'PAIR', 340],
];

export const sales = [];
let invoiceSeq = 240;

/**
 * Every sale is its own record: one customer, one total. A shop makes several
 * a day, so the fixtures generate several a day — the day's takings is the sum
 * of them, never a row of its own.
 *
 * Most are recorded as a total only, which is all the shopkeeper needs. A
 * minority are itemised because the customer asked for a proper invoice.
 */
for (let day = 0; day < 60; day += 1) {
  const saleDate = daysAgo(day);
  const fiscalYearId = day > 46 ? 'fy-2082-83' : ACTIVE_FY;

  // Saturdays are quiet; a festival week is busy.
  const saleCount = day % 7 === 5 ? between(2, 5) : between(4, 11);

  for (let n = 0; n < saleCount; n += 1) {
    const saleId = uid('sal');
    const itemised = rand() < 0.28;

    // Spread the day's sales across trading hours, earliest first.
    const hour = 10 + Math.floor((n / saleCount) * 9);
    const minute = between(0, 59);
    const at = `${saleDate}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00.000Z`;

    // Most counter sales are walk-ins with no customer record at all.
    const customer = rand() < 0.4 ? pick(customers) : null;

    if (!itemised) {
      const total = between(3, 90) * 100 + between(0, 9) * 10;
      const onCredit = customer && rand() < 0.12;

      sales.push({
        id: saleId,
        fiscalYearId,
        invoiceNo: null,
        saleDate,
        saleDateBs: adToBs(saleDate),
        customerId: customer?.id ?? null,
        saleType: 'SUMMARY',
        description: pick([
          'Readymade garments',
          'Cotton fabric',
          'Kids wear',
          'Ladies kurtha',
          'Shirting and suiting',
          'Bedsheet set',
          'Woollens',
          'Hosiery',
        ]),
        subtotal: money(total),
        discount: '0.00',
        totalAmount: money(total),
        remarks: null,
        items: [],
        payments: [
          {
            id: uid('spm'),
            saleId,
            paymentMode: onCredit ? 'CREDIT' : pick(['CASH', 'CASH', 'CASH', 'BANK']),
            amount: money(total),
            referenceNo: null,
            status: onCredit ? 'ISSUED' : 'CLEARED',
          },
        ],
        createdAt: at,
      });
      continue;
    }

    const lineCount = between(1, 4);
    const items = [];
    let subtotal = 0;

    for (let l = 0; l < lineCount; l += 1) {
      const [description, unit, unitPrice] = pick(ITEM_DESCRIPTIONS);
      const quantity = unit === 'METER' ? between(2, 12) : between(1, 6);
      const discount = rand() < 0.3 ? between(1, 4) * 50 : 0;
      const amount = quantity * unitPrice - discount;
      subtotal += amount;
      items.push({
        id: uid('sit'),
        saleId,
        description,
        quantity: quantity.toFixed(3),
        unit,
        unitPrice: money(unitPrice),
        discount: money(discount),
        amount: money(amount),
      });
    }

    const discount = rand() < 0.35 ? between(1, 6) * 100 : 0;
    const total = subtotal - discount;
    const onCredit = rand() < 0.18;
    invoiceSeq += 1;

    sales.push({
      id: saleId,
      fiscalYearId,
      invoiceNo: String(invoiceSeq),
      saleDate,
      saleDateBs: adToBs(saleDate),
      customerId: customer?.id ?? pick(customers).id,
      saleType: 'DETAILED',
      description: null,
      subtotal: money(subtotal),
      discount: money(discount),
      totalAmount: money(total),
      remarks: onCredit ? 'To be settled at month end' : null,
      items,
      payments: [
        {
          id: uid('spm'),
          saleId,
          paymentMode: onCredit ? 'CREDIT' : pick(['CASH', 'CASH', 'BANK']),
          amount: money(total),
          referenceNo: null,
          status: onCredit ? 'ISSUED' : 'CLEARED',
        },
      ],
      createdAt: at,
    });
  }
}

// Newest day first, and within a day the latest sale first.
sales.sort(
  (a, b) => b.saleDate.localeCompare(a.saleDate) || b.createdAt.localeCompare(a.createdAt),
);

/* --- Attachments ---------------------------------------------------------- */

export const attachments = purchases.slice(0, 12).map((purchase, index) => ({
  id: uid('att'),
  entityType: 'PURCHASE',
  entityId: purchase.id,
  documentType: 'PURCHASE_BILL',
  originalFileName: `bill-${purchase.billNo}.jpg`,
  storageKey: `purchases/${purchase.id}.jpg`,
  storageDriver: 'local',
  mimeType: 'image/jpeg',
  fileSize: 240_000 + index * 11_000,
  createdAt: `${purchase.billDate}T05:35:00.000Z`,
}));
