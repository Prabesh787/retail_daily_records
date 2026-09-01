import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { Banknote, CalendarRange, FileText, Phone } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import {
  Button,
  Card,
  Divider,
  EmptyState,
  SearchField,
  SegmentedControl,
  Skeleton,
} from '@/components/ui';
import {
  BalanceCard,
  DateRangeSheet,
  DetailList,
  PaymentRow,
  PurchaseRow,
  buildPresets,
  describeRange,
} from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { formatMoney } from '@/lib/format';

const TABS = [
  { value: 'ledger', label: 'Ledger' },
  { value: 'bills', label: 'Bills' },
  { value: 'payments', label: 'Payments' },
];

/**
 * A supplier's outstanding is never read from a column — it is opening balance
 * plus bills minus payments, recomputed on every request. The ledger shows that
 * same arithmetic as one column of movements so the figure can be checked by eye.
 *
 * The date range and the search box narrow the ledger, and the statement button
 * turns whatever window is showing into a report.
 */
export function SupplierDetailScreen() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [tab, setTab] = useState('ledger');
  const [range, setRange] = useState({ from: '', to: '' });
  const [rangeOpen, setRangeOpen] = useState(false);
  const [search, setSearch] = useState('');
  const query = useDebouncedValue(search);

  const { data: fiscalYear } = useQuery({
    queryKey: queryKeys.fiscalYears,
    queryFn: api.fiscalYears.active,
  });

  const params = {
    from: range.from || undefined,
    to: range.to || undefined,
    q: query || undefined,
  };

  const { data: supplier, isLoading } = useQuery({
    queryKey: queryKeys.supplier(id, params),
    queryFn: () => api.suppliers.get(id, params),
    // Keeps the previous window on screen while the next one loads, instead of
    // flashing a skeleton every time a filter moves.
    placeholderData: (previous) => previous,
  });

  // Bills and payments interleaved by date: one column of movements.
  const ledger = useMemo(() => {
    if (!supplier) return [];
    return [
      ...supplier.purchases.map((row) => ({ kind: 'purchase', date: row.billDate, row })),
      ...supplier.payments.map((row) => ({ kind: 'payment', date: row.paymentDate, row })),
    ].sort((a, b) => b.date.localeCompare(a.date));
  }, [supplier]);

  if (isLoading || !supplier) {
    return (
      <Screen title="Supplier" back>
        <div className="flex flex-col gap-3">
          <Skeleton className="rounded-card h-40" />
          <Skeleton className="rounded-card h-56" />
        </div>
      </Screen>
    );
  }

  const filtered = Boolean(range.from || range.to || query);
  const rows =
    tab === 'bills' ? supplier.purchases : tab === 'payments' ? supplier.payments : ledger;

  return (
    <Screen title={supplier.name} eyebrow={supplier.contactPerson} back>
      <div className="flex flex-col gap-4">
        <BalanceCard
          amount={supplier.balance.outstanding}
          cleared={supplier.balance.clearedTotal}
          uncleared={supplier.balance.unclearedTotal}
          caption={`${supplier.balance.billCount} bills · ${supplier.balance.paymentCount} payments`}
        />

        <div className="grid grid-cols-3 gap-2">
          <Button
            variant="secondary"
            size="sm"
            icon={Phone}
            disabled={!supplier.phone}
            onClick={() => {
              window.location.href = `tel:${supplier.phone}`;
            }}
          >
            Call
          </Button>
          <Button
            variant="secondary"
            size="sm"
            icon={FileText}
            onClick={() =>
              navigate(`/suppliers/${supplier.id}/statement?from=${range.from}&to=${range.to}`)
            }
          >
            Report
          </Button>
          <Button
            size="sm"
            icon={Banknote}
            onClick={() => navigate(`/payments/new?supplierId=${supplier.id}`)}
          >
            Pay
          </Button>
        </div>

        <div className="flex flex-col gap-3">
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Bill no., voucher or cheque no."
          />

          <button
            type="button"
            onClick={() => setRangeOpen(true)}
            className="bg-surface border-line-strong rounded-tile text-ink-muted flex h-11 items-center gap-2 border px-3 text-[13.5px] font-semibold"
          >
            <CalendarRange size={16} />
            {describeRange(range, buildPresets(fiscalYear))}
          </button>
        </div>

        {/* When a window is applied the totals for that window are what matter,
            not the all-time position above. */}
        {filtered ? (
          <Card>
            <div className="flex items-baseline justify-between gap-3">
              <span className="label-section">In this range</span>
              <span className="text-ink-subtle text-[11.5px]">
                {supplier.window.billCount} bills · {supplier.window.paymentCount} payments
              </span>
            </div>
            <div className="mt-2 grid grid-cols-3 gap-3">
              <WindowFigure label="Opened at" value={supplier.window.openingAsOf} />
              <WindowFigure label="Billed" value={supplier.window.purchaseTotal} tone="text-out" />
              <WindowFigure label="Paid" value={supplier.window.paymentTotal} tone="text-in" />
            </div>
            <div className="border-line mt-3 flex items-baseline justify-between border-t pt-3">
              <span className="text-ink-muted text-[13px] font-semibold">Closing</span>
              <span className="text-[17px] font-bold tabular-nums">
                {formatMoney(supplier.window.closing)}
              </span>
            </div>
          </Card>
        ) : null}

        <SegmentedControl options={TABS} value={tab} onChange={setTab} />

        {rows.length === 0 ? (
          <Card>
            <EmptyState
              icon={FileText}
              title="Nothing in this range"
              message="Widen the dates, or clear the search."
            />
          </Card>
        ) : (
          <Card padded={false}>
            {rows.map((entry, index) => {
              const kind = tab === 'ledger' ? entry.kind : tab === 'bills' ? 'purchase' : 'payment';
              const row = tab === 'ledger' ? entry.row : entry;
              return (
                <div key={`${kind}-${row.id}`}>
                  {index > 0 ? <Divider /> : null}
                  {kind === 'purchase' ? (
                    <PurchaseRow purchase={{ ...row, supplier }} />
                  ) : (
                    <PaymentRow payment={{ ...row, supplier }} showSupplier={false} />
                  )}
                </div>
              );
            })}
          </Card>
        )}

        <DetailList
          rows={[
            { label: 'Contact', value: supplier.contactPerson },
            { label: 'Phone', value: supplier.phone, mono: true },
            { label: 'Address', value: supplier.address },
            { label: 'PAN', value: supplier.pan, mono: true },
            { label: 'Opening balance', value: formatMoney(supplier.openingBalance), mono: true },
            {
              label: 'Total billed',
              value: formatMoney(supplier.balance.purchaseTotal),
              mono: true,
            },
            { label: 'Remarks', value: supplier.remarks },
          ]}
        />
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

function WindowFigure({ label, value, tone }) {
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
