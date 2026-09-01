import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { CalendarCheck } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import {
  Card,
  Divider,
  EmptyState,
  SegmentedControl,
  SkeletonRows,
  StatTile,
} from '@/components/ui';
import { ChequeRow, GroupHeader } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { daysUntil, formatMoney, formatMoneyShort, toNumber } from '@/lib/format';

const FILTERS = [
  { value: 'ISSUED', label: 'Not cleared' },
  { value: 'CLEARED', label: 'Cleared' },
  { value: 'ALL', label: 'All' },
];

/**
 * Cheques ordered by the date written on them — the order the money has to be
 * in the account. Overdue and due-this-week are split out because those are
 * the two buckets that need action today.
 */
export function ChequeRegisterScreen() {
  const [filter, setFilter] = useState('ISSUED');

  const params = { status: filter === 'ALL' ? undefined : filter };
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.chequeRegister(params),
    queryFn: () => api.supplierPayments.chequeRegister(params),
  });

  // Memoised so the bucket split below does not re-run on every render.
  const rows = useMemo(() => data?.data ?? [], [data]);

  const buckets = useMemo(() => {
    const groups = { overdue: [], week: [], later: [] };
    for (const row of rows) {
      const days = daysUntil(row.chequeDate);
      if (days < 0) groups.overdue.push(row);
      else if (days <= 7) groups.week.push(row);
      else groups.later.push(row);
    }
    return groups;
  }, [rows]);

  const total = rows.reduce((acc, row) => acc + toNumber(row.amount), 0);
  const weekTotal = buckets.week.reduce((acc, row) => acc + toNumber(row.amount), 0);

  return (
    <Screen
      title="Cheque register"
      eyebrow="Ordered by the date on the cheque"
      back
      flush
      headerExtra={
        <div className="bg-surface/80 px-4 pb-3 backdrop-blur-xl">
          <SegmentedControl options={FILTERS} value={filter} onChange={setFilter} />
        </div>
      }
    >
      <div className="grid grid-cols-2 gap-3 px-4 pb-4">
        <StatTile
          label={filter === 'CLEARED' ? 'Cleared' : 'Awaiting clearance'}
          value={formatMoneyShort(total)}
          foot={`${rows.length} cheque${rows.length === 1 ? '' : 's'}`}
          tone={filter === 'CLEARED' ? 'in' : 'pending'}
        />
        <StatTile
          label="Due within 7 days"
          value={formatMoneyShort(weekTotal)}
          foot={`${buckets.week.length} to cover`}
          tone="out"
        />
      </div>

      {isLoading ? <SkeletonRows /> : null}

      {data && rows.length === 0 ? (
        <EmptyState
          icon={CalendarCheck}
          title="Nothing outstanding"
          message="Every cheque handed over has cleared the bank."
        />
      ) : null}

      <div className="flex flex-col gap-4 px-4">
        <Bucket label="Overdue" rows={buckets.overdue} />
        <Bucket label="Next 7 days" rows={buckets.week} />
        <Bucket label="Later" rows={buckets.later} />
      </div>
    </Screen>
  );
}

function Bucket({ label, rows }) {
  if (rows.length === 0) return null;
  const total = rows.reduce((acc, row) => acc + toNumber(row.amount), 0);

  return (
    <Card padded={false}>
      <GroupHeader label={label} total={formatMoney(total, { decimals: false })} />
      {rows.map((payment, index) => {
        const days = daysUntil(payment.chequeDate);
        return (
          <div key={payment.id}>
            {index > 0 ? <Divider /> : null}
            <ChequeRow
              payment={payment}
              dueLabel={
                payment.status === 'CLEARED'
                  ? null
                  : days < 0
                    ? `${Math.abs(days)}d overdue`
                    : days === 0
                      ? 'today'
                      : `in ${days}d`
              }
            />
          </div>
        );
      })}
    </Card>
  );
}
