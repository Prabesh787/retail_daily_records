import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useParams, useSearchParams } from 'react-router-dom';
import { CalendarRange, Printer } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Badge, Button, Card, Divider, IconButton, Skeleton } from '@/components/ui';
import { DateRangeSheet, buildPresets, describeRange } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { PAYMENT_STATUS, SUPPLIER_PAYMENT_MODE } from '@/lib/constants';
import { formatDateAd, formatDateBs, formatMoney, toNumber } from '@/lib/format';

/**
 * A supplier statement for one date window: the position carried in, every
 * movement in order, and the position carried out.
 *
 * Bills and payments are interleaved oldest-first with a running balance, which
 * is the form a supplier will actually reconcile against. `Print` hands it to
 * the OS print dialog — which is also how it becomes a PDF to share.
 */
export function SupplierStatementScreen() {
  const { id } = useParams();
  const [searchParams] = useSearchParams();

  const [range, setRange] = useState({
    from: searchParams.get('from') ?? '',
    to: searchParams.get('to') ?? '',
  });
  const [rangeOpen, setRangeOpen] = useState(false);

  const { data: fiscalYear } = useQuery({
    queryKey: queryKeys.fiscalYears,
    queryFn: api.fiscalYears.active,
  });

  const params = { from: range.from || undefined, to: range.to || undefined };
  const { data: supplier, isLoading } = useQuery({
    queryKey: queryKeys.supplier(id, params),
    queryFn: () => api.suppliers.get(id, params),
    placeholderData: (previous) => previous,
  });

  /**
   * Oldest first with a running balance. A cancelled payment is listed for the
   * audit trail but moves nothing, which is why it is skipped in the running
   * figure rather than left out of the statement.
   */
  const lines = useMemo(() => {
    if (!supplier) return [];

    const movements = [
      ...supplier.purchases.map((row) => ({
        id: row.id,
        kind: 'bill',
        date: row.billDate,
        dateBs: row.billDateBs,
        reference: `Bill ${row.billNo}`,
        detail: row.description,
        debit: toNumber(row.amount),
        credit: 0,
      })),
      ...supplier.payments.map((row) => ({
        id: row.id,
        kind: 'payment',
        date: row.paymentDate,
        dateBs: row.paymentDateBs,
        reference: row.voucherNo
          ? `Voucher ${row.voucherNo}`
          : SUPPLIER_PAYMENT_MODE[row.paymentMode].label,
        detail: [
          SUPPLIER_PAYMENT_MODE[row.paymentMode].label,
          row.chequeNo ? `cheque ${row.chequeNo}` : null,
          row.purchase ? `against bill ${row.purchase.billNo}` : null,
        ]
          .filter(Boolean)
          .join(' · '),
        status: row.status,
        debit: 0,
        credit: row.status === 'CANCELLED' ? 0 : toNumber(row.amount),
      })),
    ].sort((a, b) => a.date.localeCompare(b.date) || a.kind.localeCompare(b.kind));

    let running = toNumber(supplier.window.openingAsOf);
    return movements.map((movement) => {
      running += movement.debit - movement.credit;
      return { ...movement, balance: running };
    });
  }, [supplier]);

  if (isLoading || !supplier) {
    return (
      <Screen title="Statement" back>
        <Skeleton className="rounded-card h-64" />
      </Screen>
    );
  }

  const { window } = supplier;

  return (
    <Screen
      title="Statement"
      eyebrow={supplier.name}
      back
      actions={<IconButton icon={Printer} label="Print" onClick={() => globalThis.print()} />}
    >
      <div className="flex flex-col gap-4">
        <button
          type="button"
          onClick={() => setRangeOpen(true)}
          className="bg-surface border-line-strong rounded-tile text-ink-muted flex h-11 items-center gap-2 border px-3 text-[13.5px] font-semibold"
        >
          <CalendarRange size={16} />
          {describeRange(range, buildPresets(fiscalYear))}
        </button>

        <Card>
          <p className="label-section">Closing balance</p>
          <p
            className={`text-[30px] font-bold tracking-[-0.035em] tabular-nums ${
              toNumber(window.closing) > 0 ? 'text-out' : 'text-in'
            }`}
          >
            {formatMoney(window.closing)}
          </p>
          <p className="text-ink-subtle text-[11.5px]">
            {range.from ? formatDateAd(range.from) : 'Beginning'} —{' '}
            {range.to ? formatDateAd(range.to) : 'today'}
          </p>

          <div className="border-line mt-3 grid grid-cols-3 gap-3 border-t pt-3">
            <Figure label="Opening" value={window.openingAsOf} />
            <Figure label="Billed" value={window.purchaseTotal} tone="text-out" />
            <Figure label="Paid" value={window.paymentTotal} tone="text-in" />
          </div>

          {toNumber(window.unclearedTotal) > 0 ? (
            <p className="bg-pending-soft text-pending rounded-tile mt-3 px-3 py-2 text-[12.5px]">
              {formatMoney(window.unclearedTotal, { decimals: false })} of the payments above are
              cheques that have not cleared the bank yet.
            </p>
          ) : null}
        </Card>

        <Card padded={false}>
          <div className="bg-sunken text-ink-subtle flex items-center justify-between px-4 py-2 text-[11.5px] font-bold tracking-[0.05em] uppercase">
            <span>Opening balance</span>
            <span className="tabular-nums">{formatMoney(window.openingAsOf)}</span>
          </div>

          {lines.length === 0 ? (
            <p className="text-ink-muted p-4 text-[13.5px]">
              No movements in this range. The balance carried in is the balance carried out.
            </p>
          ) : (
            lines.map((line, index) => (
              <div key={`${line.kind}-${line.id}`}>
                {index > 0 ? <Divider /> : null}
                <div className="flex items-start gap-3 px-4 py-3">
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-2">
                      <span className="truncate text-[13.5px] font-semibold">{line.reference}</span>
                      {line.status && line.status !== 'CLEARED' ? (
                        <Badge tone={PAYMENT_STATUS[line.status].tone}>
                          {PAYMENT_STATUS[line.status].label}
                        </Badge>
                      ) : null}
                    </span>
                    <span className="text-ink-muted block truncate text-[12px]">
                      {formatDateBs(line.dateBs) ?? formatDateAd(line.date)}
                      {line.detail ? ` · ${line.detail}` : ''}
                    </span>
                  </span>

                  <span className="flex shrink-0 flex-col items-end">
                    <span
                      className={`text-[13.5px] font-bold tabular-nums ${
                        line.debit ? 'text-out' : 'text-in'
                      }`}
                    >
                      {line.debit
                        ? `+ ${formatMoney(line.debit, { decimals: false, symbol: false })}`
                        : `− ${formatMoney(line.credit, { decimals: false, symbol: false })}`}
                    </span>
                    <span className="text-ink-subtle text-[11.5px] tabular-nums">
                      {formatMoney(line.balance, { decimals: false })}
                    </span>
                  </span>
                </div>
              </div>
            ))
          )}

          <div className="bg-sunken flex items-center justify-between px-4 py-3 text-[13px] font-bold">
            <span>Closing balance</span>
            <span className="tabular-nums">{formatMoney(window.closing)}</span>
          </div>
        </Card>

        <Button variant="secondary" icon={Printer} block onClick={() => globalThis.print()}>
          Print or save as PDF
        </Button>
      </div>

      <DateRangeSheet
        open={rangeOpen}
        onClose={() => setRangeOpen(false)}
        value={range}
        onApply={setRange}
        fiscalYear={fiscalYear}
      />
    </Screen>
  );
}

function Figure({ label, value, tone }) {
  return (
    <span className="text-ink-muted text-[11.5px]">
      {label}
      <strong
        className={`mt-px block text-[15px] font-semibold tabular-nums ${tone ?? 'text-ink'}`}
      >
        {formatMoney(value, { decimals: false })}
      </strong>
    </span>
  );
}
