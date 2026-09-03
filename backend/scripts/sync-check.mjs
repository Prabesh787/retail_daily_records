/**
 * End-to-end exercise of the sync service against a live database.
 *
 *     npm run sync:check
 *
 * The repository has no test runner, and the merge rules in `modules/sync` are
 * the kind that are only really proven against a real database - triggers,
 * transactions, constraint failures and a keyset cursor cannot be asserted
 * against a mock. So this is a script rather than a suite: it pushes a whole
 * shop's worth of documents, checks every rule the module claims, then removes
 * what it made and puts the active fiscal year back the way it found it.
 *
 * It writes to whatever `DATABASE_URL` points at, so it refuses to run in
 * production.
 */

// Printing is how this reports; the lint rule is aimed at leftovers in the API.
/* eslint-disable no-console */
import { env } from '../src/config/index.js';
import { prisma } from '../src/database/prisma-client.js';
import { syncService } from '../src/modules/sync/sync.service.js';

if (env.isProduction) {
  console.error('sync-check writes and deletes records. It will not run against production.');
  process.exit(1);
}

const DEVICE = 'test-device-1';
const OTHER_DEVICE = 'test-device-2';
const T = Date.now();

const ids = {
  fy: 'aaaaaaaa-0000-4000-8000-000000000001',
  supplier: 'aaaaaaaa-0000-4000-8000-000000000002',
  customer: 'aaaaaaaa-0000-4000-8000-000000000003',
  purchase: 'aaaaaaaa-0000-4000-8000-000000000004',
  payment: 'aaaaaaaa-0000-4000-8000-000000000005',
  sale: 'aaaaaaaa-0000-4000-8000-000000000006',
  item1: 'aaaaaaaa-0000-4000-8000-000000000007',
  item2: 'aaaaaaaa-0000-4000-8000-000000000008',
  salePayment: 'aaaaaaaa-0000-4000-8000-000000000009',
};

let failures = 0;
const check = (label, ok, detail) => {
  if (!ok) failures += 1;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${detail === undefined ? '' : ` -> ${detail}`}`);
};

const meta = (updatedAt, deviceId = DEVICE) => ({
  created_at: T,
  updated_at: updatedAt,
  is_deleted: false,
  device_id: deviceId,
});

const op = (entity, entityId, payload, updatedAt, operation = 'upsert') => ({
  entity,
  entity_id: entityId,
  operation,
  updated_at: updatedAt,
  payload: { id: entityId, ...payload, ...meta(updatedAt, payload.device_id ?? DEVICE) },
});

const supplierPayload = (name = 'Sync Test Supplier') => ({
  name,
  contactPerson: 'Ram',
  phone: '9800000000',
  email: null,
  address: 'Birgunj',
  pan: '301234567',
  openingBalance: '12500.00',
  isActive: true,
  remarks: null,
});

const previouslyActive = await prisma.fiscalYear.findFirst({ where: { isActive: true } });

try {
  // ---- Push a whole shop's worth of documents, in dependency order --------
  const batch = [
    op(
      'fiscal_years',
      ids.fy,
      {
        name: 'SYNC-TEST',
        startDate: '2025-07-17',
        endDate: '2026-07-16',
        startDateBs: '2082-04-01',
        endDateBs: '2083-03-32',
        isActive: true,
      },
      T,
    ),
    op('suppliers', ids.supplier, supplierPayload(), T),
    op(
      'customers',
      ids.customer,
      { name: 'Sync Test Customer', phone: null, address: null, pan: null, remarks: null },
      T,
    ),
    op(
      'purchases',
      ids.purchase,
      {
        fiscalYearId: ids.fy,
        supplierId: ids.supplier,
        billNo: 'SYNC-4521',
        billDate: '2026-09-01',
        billDateBs: '2083-05-16',
        description: 'Cotton shirting',
        amount: '48250.75',
        remarks: null,
      },
      T,
    ),
    op(
      'supplier_payments',
      ids.payment,
      {
        fiscalYearId: ids.fy,
        supplierId: ids.supplier,
        purchaseId: ids.purchase,
        voucherNo: 'SYNC-V1',
        paymentDate: '2026-09-02',
        paymentDateBs: '2083-05-17',
        paymentMode: 'CHEQUE',
        amount: '20000.00',
        chequeNo: '00123',
        chequeDate: '2026-09-20',
        chequeDateBs: '2083-06-04',
        referenceNo: null,
        clearedDate: null,
        status: 'ISSUED',
        description: null,
        remarks: null,
      },
      T,
    ),
    op(
      'sales',
      ids.sale,
      {
        fiscalYearId: ids.fy,
        invoiceNo: 'SYNC-INV-9',
        saleDate: '2026-09-02',
        saleDateBs: '2083-05-17',
        customerId: ids.customer,
        saleType: 'DETAILED',
        description: null,
        subtotal: '9999.00',
        discount: '200.00',
        totalAmount: '9999.00',
        remarks: null,
        items: [
          {
            id: ids.item2,
            saleId: ids.sale,
            description: 'Trouser',
            quantity: '1.000',
            unit: 'PCS',
            unitPrice: '800.00',
            discount: '0.00',
            amount: '0.00',
            sortOrder: 1,
          },
          {
            id: ids.item1,
            saleId: ids.sale,
            description: 'Shirt',
            quantity: '2.000',
            unit: 'PCS',
            unitPrice: '1200.00',
            discount: '0.00',
            amount: '0.00',
            sortOrder: 0,
          },
        ],
        payments: [
          {
            id: ids.salePayment,
            saleId: ids.sale,
            paymentMode: 'CASH',
            amount: '3000.00',
            referenceNo: null,
            chequeNo: null,
            chequeDate: null,
            clearedDate: null,
            status: 'CLEARED',
            remarks: null,
          },
        ],
      },
      T,
    ),
  ];

  const push = await syncService.push({ deviceId: DEVICE, operations: batch }, null);
  check(
    'push: every operation accepted',
    push.results.every((r) => r.status === 'accepted'),
    push.results.map((r) => `${r.status}${r.message ? `(${r.message})` : ''}`).join(' '),
  );

  const storedSale = await prisma.sale.findUnique({
    where: { id: ids.sale },
    include: { items: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] }, payments: true },
  });
  check(
    'sale: totals recomputed, client figures ignored',
    String(storedSale.subtotal) === '3200' && String(storedSale.totalAmount) === '3000',
    `subtotal=${storedSale.subtotal} discount=${storedSale.discount} total=${storedSale.totalAmount}`,
  );
  check(
    'sale: lines kept the client ids',
    storedSale.items.map((i) => i.id).join(',') === `${ids.item1},${ids.item2}`,
    storedSale.items.map((i) => `${i.sortOrder}:${i.description}`).join(' '),
  );
  check(
    'sale: client clock stored as the merge clock',
    Number(storedSale.syncUpdatedAt) === T,
    `${storedSale.syncUpdatedAt} vs ${T}`,
  );
  check('sale: created_at came from the device', storedSale.createdAt.getTime() === T);

  const activeYears = await prisma.fiscalYear.count({ where: { isActive: true } });
  check('fiscal year: still exactly one active', activeYears === 1, `${activeYears} active`);

  // ---- Replaying the same batch must change nothing -----------------------
  const replay = await syncService.push({ deviceId: DEVICE, operations: batch }, null);
  const itemCount = await prisma.saleItem.count({ where: { saleId: ids.sale } });
  check(
    'replay: accepted again',
    replay.results.every((r) => r.status === 'accepted'),
  );
  check('replay: no duplicate invoice lines', itemCount === 2, `${itemCount} lines`);

  // ---- Conflicts ----------------------------------------------------------
  const stale = await syncService.push(
    {
      deviceId: OTHER_DEVICE,
      operations: [op('suppliers', ids.supplier, supplierPayload('Stale Name'), T - 5000)],
    },
    null,
  );
  const staleResult = stale.results[0];
  check(
    'stale push: reported as a conflict',
    staleResult.status === 'conflict',
    staleResult.message,
  );
  check(
    'stale push: carries the server row for the client to merge',
    staleResult.server_row?.name === 'Sync Test Supplier' &&
      staleResult.server_row?.updated_at === T &&
      staleResult.server_row?.is_deleted === false &&
      staleResult.server_row?.openingBalance === '12500.00',
    JSON.stringify({
      name: staleResult.server_row?.name,
      updated_at: staleResult.server_row?.updated_at,
      openingBalance: staleResult.server_row?.openingBalance,
    }),
  );
  const unchanged = await prisma.supplier.findUnique({ where: { id: ids.supplier } });
  check('stale push: nothing was written', unchanged.name === 'Sync Test Supplier');

  const newer = await syncService.push(
    {
      deviceId: OTHER_DEVICE,
      operations: [
        op(
          'suppliers',
          ids.supplier,
          { ...supplierPayload('Renamed By Other Device'), device_id: OTHER_DEVICE },
          T + 5000,
        ),
      ],
    },
    null,
  );
  const renamed = await prisma.supplier.findUnique({ where: { id: ids.supplier } });
  check('newer push: accepted', newer.results[0].status === 'accepted', newer.results[0].message);
  check(
    'newer push: applied and attributed to the writing device',
    renamed.name === 'Renamed By Other Device' && renamed.deviceId === OTHER_DEVICE,
  );

  // ---- A write from the web app has to look newer to the phone -----------
  const beforeWebEdit = Number(renamed.syncUpdatedAt);
  await prisma.supplier.update({ where: { id: ids.supplier }, data: { phone: '9811111111' } });
  const afterWebEdit = await prisma.supplier.findUnique({ where: { id: ids.supplier } });
  const restamped = Number(afterWebEdit.syncUpdatedAt);
  check(
    'web edit: the trigger restamped the merge clock with server time',
    restamped !== beforeWebEdit && Math.abs(restamped - Date.now()) < 5000,
    `${beforeWebEdit} -> ${restamped} (now ${Date.now()})`,
  );

  // ---- Pull ---------------------------------------------------------------
  console.log('     (waiting out the pull visibility lag)');
  await new Promise((resolve) => setTimeout(resolve, 2500));

  const suppliersPage = await syncService.pull({ entity: 'suppliers', limit: 200 });
  const pulledSupplier = suppliersPage.rows.find((row) => row.id === ids.supplier);
  check('pull: the supplier comes back', Boolean(pulledSupplier));
  check(
    'pull: money is a fixed string, sync keys are snake_case',
    pulledSupplier.openingBalance === '12500.00' &&
      typeof pulledSupplier.updated_at === 'number' &&
      pulledSupplier.is_deleted === false &&
      pulledSupplier.device_id === OTHER_DEVICE,
    JSON.stringify({
      openingBalance: pulledSupplier.openingBalance,
      updated_at: pulledSupplier.updated_at,
      device_id: pulledSupplier.device_id,
    }),
  );
  check(
    'pull: no internal columns leak',
    !('syncUpdatedAt' in pulledSupplier) &&
      !('deviceId' in pulledSupplier) &&
      !('updatedAt' in pulledSupplier),
    Object.keys(pulledSupplier).join(','),
  );

  const salesPage = await syncService.pull({ entity: 'sales', limit: 200 });
  const pulledSale = salesPage.rows.find((row) => row.id === ids.sale);
  check(
    'pull: a sale arrives whole, lines in order',
    pulledSale.items.length === 2 &&
      pulledSale.items[0].description === 'Shirt' &&
      pulledSale.payments.length === 1 &&
      pulledSale.totalAmount === '3000.00' &&
      pulledSale.saleDate === '2026-09-02',
    JSON.stringify({
      total: pulledSale.totalAmount,
      saleDate: pulledSale.saleDate,
      items: pulledSale.items.map((i) => i.description),
    }),
  );

  // Paging: one row at a time, following the cursor to the end.
  let cursor;
  let pages = 0;
  const seen = new Set();
  do {
    const page = await syncService.pull({ entity: 'suppliers', cursor, limit: 1 });
    page.rows.forEach((row) => seen.add(row.id));
    cursor = page.next_cursor;
    pages += 1;
    if (!page.has_more) break;
  } while (pages < 20);
  check(
    'pull: paging one row at a time reaches every supplier',
    seen.size === (await prisma.supplier.count()),
    `${seen.size} of ${await prisma.supplier.count()} in ${pages} pages`,
  );

  const upToDate = await syncService.pull({ entity: 'suppliers', cursor, limit: 200 });
  check(
    'pull: an exhausted cursor returns nothing and keeps its place',
    upToDate.rows.length === 0 && upToDate.has_more === false && upToDate.next_cursor === cursor,
  );

  // ---- Deletes ------------------------------------------------------------
  const refused = await syncService.push(
    {
      deviceId: DEVICE,
      operations: [
        op(
          'suppliers',
          ids.supplier,
          { ...supplierPayload('Renamed By Other Device'), is_deleted: true },
          T + 9000,
          'delete',
        ),
      ],
    },
    null,
  );
  check(
    'delete: a supplier with documents is refused, with a reason',
    refused.results[0].status === 'error' && refused.results[0].retryable === false,
    refused.results[0].message,
  );
  check(
    'delete: the supplier is still there',
    (await prisma.supplier.count({ where: { id: ids.supplier } })) === 1,
  );

  const deleteSale = await syncService.push(
    {
      deviceId: DEVICE,
      operations: [
        op(
          'sales',
          ids.sale,
          {
            fiscalYearId: ids.fy,
            saleDate: '2026-09-02',
            saleDateBs: '2083-05-17',
            saleType: 'SUMMARY',
            totalAmount: '3200.00',
            items: [],
            payments: [],
            is_deleted: true,
          },
          T + 9000,
          'delete',
        ),
      ],
    },
    null,
  );
  check(
    'delete: the sale is accepted',
    deleteSale.results[0].status === 'accepted',
    deleteSale.results[0].message,
  );
  check('delete: the sale is gone', (await prisma.sale.count({ where: { id: ids.sale } })) === 0);
  check(
    'delete: its lines went with it',
    (await prisma.saleItem.count({ where: { saleId: ids.sale } })) === 0,
  );

  const tombstone = await prisma.syncTombstone.findUnique({
    where: { entity_entityId: { entity: 'sales', entityId: ids.sale } },
  });
  check(
    'delete: a tombstone was recorded, with the deleting device',
    Boolean(tombstone) &&
      tombstone.deviceId === DEVICE &&
      Number(tombstone.syncUpdatedAt) === T + 9000,
  );

  console.log('     (waiting out the pull visibility lag)');
  await new Promise((resolve) => setTimeout(resolve, 2500));

  const afterDelete = await syncService.pull({ entity: 'sales', limit: 200 });
  const pulledTombstone = afterDelete.rows.find((row) => row.id === ids.sale);
  check(
    'pull: the deletion travels as a tombstone',
    pulledTombstone?.is_deleted === true && pulledTombstone.updated_at === T + 9000,
    JSON.stringify(pulledTombstone),
  );

  // Re-pushing the deleted sale with an older timestamp must not resurrect it.
  const resurrect = await syncService.push(
    {
      deviceId: OTHER_DEVICE,
      operations: [
        op(
          'sales',
          ids.sale,
          {
            fiscalYearId: ids.fy,
            invoiceNo: 'SYNC-INV-9',
            saleDate: '2026-09-02',
            saleDateBs: '2083-05-17',
            customerId: ids.customer,
            saleType: 'SUMMARY',
            totalAmount: '3200.00',
            items: [],
            payments: [],
          },
          T + 1000,
        ),
      ],
    },
    null,
  );
  check(
    'delete: an older edit does not resurrect the row',
    resurrect.results[0].status === 'conflict' &&
      resurrect.results[0].server_row?.is_deleted === true,
    resurrect.results[0].message,
  );
  check('delete: still gone', (await prisma.sale.count({ where: { id: ids.sale } })) === 0);

  // A newer edit is a deliberate re-entry and must be allowed back in.
  const reentry = await syncService.push(
    {
      deviceId: OTHER_DEVICE,
      operations: [
        op(
          'sales',
          ids.sale,
          {
            fiscalYearId: ids.fy,
            invoiceNo: 'SYNC-INV-9',
            saleDate: '2026-09-02',
            saleDateBs: '2083-05-17',
            customerId: ids.customer,
            saleType: 'SUMMARY',
            totalAmount: '3200.00',
            items: [],
            payments: [],
          },
          T + 20000,
        ),
      ],
    },
    null,
  );
  check(
    'delete: a newer edit re-creates the row',
    reentry.results[0].status === 'accepted',
    reentry.results[0].message,
  );
  check(
    'delete: and clears the tombstone',
    (await prisma.syncTombstone.count({ where: { entity: 'sales', entityId: ids.sale } })) === 0,
  );

  // ---- Rejections ---------------------------------------------------------
  const bad = await syncService.push(
    {
      deviceId: DEVICE,
      operations: [
        op(
          'purchases',
          'aaaaaaaa-0000-4000-8000-0000000000ff',
          {
            fiscalYearId: ids.fy,
            supplierId: ids.supplier,
            billNo: '',
            billDate: '2026-09-01',
            billDateBs: null,
            description: null,
            amount: '10.00',
            remarks: null,
          },
          T,
        ),
        op(
          'purchases',
          'aaaaaaaa-0000-4000-8000-0000000000fe',
          {
            fiscalYearId: ids.fy,
            supplierId: 'aaaaaaaa-0000-4000-8000-0000000000aa',
            billNo: 'GHOST',
            billDate: '2026-09-01',
            billDateBs: null,
            description: null,
            amount: '10.00',
            remarks: null,
          },
          T,
        ),
        op(
          'purchases',
          'aaaaaaaa-0000-4000-8000-0000000000fd',
          {
            fiscalYearId: ids.fy,
            supplierId: ids.supplier,
            billNo: 'SYNC-4521',
            billDate: '2026-09-01',
            billDateBs: null,
            description: null,
            amount: '10.00',
            remarks: null,
          },
          T,
        ),
      ],
    },
    null,
  );
  check(
    'reject: an invalid row is refused, not retried forever',
    bad.results[0].status === 'error' && bad.results[0].retryable === false,
    bad.results[0].message,
  );
  check(
    'reject: a missing parent is refused but retryable',
    bad.results[1].status === 'error' && bad.results[1].retryable === true,
    bad.results[1].message,
  );
  check(
    'reject: a duplicate bill number is refused',
    bad.results[2].status === 'error' && bad.results[2].retryable === false,
    bad.results[2].message,
  );
  check('reject: one bad row does not stop the batch', bad.results.length === 3);
} finally {
  // ---- Put the database back the way it was -------------------------------
  await prisma.salePayment.deleteMany({ where: { saleId: ids.sale } });
  await prisma.saleItem.deleteMany({ where: { saleId: ids.sale } });
  await prisma.sale.deleteMany({ where: { id: ids.sale } });
  await prisma.supplierPayment.deleteMany({ where: { id: ids.payment } });
  await prisma.purchase.deleteMany({
    where: {
      id: {
        in: [
          ids.purchase,
          'aaaaaaaa-0000-4000-8000-0000000000ff',
          'aaaaaaaa-0000-4000-8000-0000000000fe',
          'aaaaaaaa-0000-4000-8000-0000000000fd',
        ],
      },
    },
  });
  await prisma.supplier.deleteMany({ where: { id: ids.supplier } });
  await prisma.customer.deleteMany({ where: { id: ids.customer } });
  await prisma.fiscalYear.deleteMany({ where: { id: ids.fy } });
  await prisma.syncTombstone.deleteMany({ where: { entityId: { in: Object.values(ids) } } });
  if (previouslyActive) {
    await prisma.fiscalYear.update({
      where: { id: previouslyActive.id },
      data: { isActive: true },
    });
  }

  const left = {
    fiscalYear: await prisma.fiscalYear.count(),
    supplier: await prisma.supplier.count(),
    customer: await prisma.customer.count(),
    purchase: await prisma.purchase.count(),
    sale: await prisma.sale.count(),
    tombstones: await prisma.syncTombstone.count(),
    activeYear: (await prisma.fiscalYear.findFirst({ where: { isActive: true } }))?.name ?? null,
  };
  console.log('\ncleanup:', JSON.stringify(left));
  await prisma.$disconnect();
  console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}
