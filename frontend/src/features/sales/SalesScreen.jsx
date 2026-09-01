import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Receipt } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Fab } from '@/components/layout/Fab';
import { Card, Divider, EmptyState, SegmentedControl, SkeletonRows } from '@/components/ui';
import { GroupHeader, SaleRow } from '@/components/domain';
import { groupByDay } from '@/lib/group-by-day';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { formatMoney, formatRelativeDay, toNumber } from '@/lib/format';

const FILTERS = [
  { value: 'ALL', label: 'All' },
  { value: 'SUMMARY', label: 'Total only' },
  { value: 'DETAILED', label: 'Itemised' },
];

/**
 * Every sale is its own row. They are grouped by day with the day's takings on
 * the header — the total is derived from the sales under it, so it can never
 * disagree with them. Tapping a header opens that day on its own.
 */
export function SalesScreen() {
  const [filter, setFilter] = useState('ALL');

  const params = { saleType: filter === 'ALL' ? undefined : filter, limit: 60 };
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.sales(params),
    queryFn: () => api.sales.list(params),
  });

  const groups = useMemo(() => groupByDay(data?.data ?? [], 'saleDate', 'totalAmount'), [data]);
  const total = (data?.data ?? []).reduce((acc, row) => acc + toNumber(row.totalAmount), 0);

  return (
    <Screen
      title="Sales"
      eyebrow={
        data ? `${data.meta.total} sales · ${formatMoney(total, { decimals: false })}` : null
      }
      flush
      reserveBottom={80}
      headerExtra={
        <div className="bg-surface/80 px-4 pb-3 backdrop-blur-xl">
          <SegmentedControl options={FILTERS} value={filter} onChange={setFilter} />
        </div>
      }
    >
      {isLoading ? <SkeletonRows /> : null}

      {data && groups.length === 0 ? (
        <EmptyState
          icon={Receipt}
          title="Nothing recorded yet"
          message="Record a sale with its total, or write a customer an itemised invoice."
        />
      ) : null}

      <div className="flex flex-col gap-4 px-4">
        {groups.map((group) => (
          <Card key={group.date} padded={false}>
            <GroupHeader
              to={`/sales/day/${group.date}`}
              label={formatRelativeDay(group.date)}
              count={group.rows.length}
              total={formatMoney(group.total, { decimals: false })}
            />
            {group.rows.map((sale, index) => (
              <div key={sale.id}>
                {index > 0 ? <Divider /> : null}
                <SaleRow sale={sale} />
              </div>
            ))}
          </Card>
        ))}
      </div>

      <Fab to="/sales/new" label="New sale" />
    </Screen>
  );
}
