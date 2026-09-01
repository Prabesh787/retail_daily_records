import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Inbox } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Fab } from '@/components/layout/Fab';
import { Card, EmptyState, SearchField, SkeletonRows, Divider } from '@/components/ui';
import { GroupHeader, PurchaseRow } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { groupByDay } from '@/lib/group-by-day';
import { formatMoney, formatRelativeDay, toNumber } from '@/lib/format';

/**
 * Bills in, newest first, grouped by the day they were entered. The group
 * header carries the day's total, which is the number the shopkeeper is
 * actually scanning for.
 */
export function PurchasesScreen() {
  const [search, setSearch] = useState('');
  const query = useDebouncedValue(search);

  const params = { q: query || undefined, limit: 50 };
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.purchases(params),
    queryFn: () => api.purchases.list(params),
  });

  const groups = useMemo(() => groupByDay(data?.data ?? [], 'billDate', 'amount'), [data]);
  const total = (data?.data ?? []).reduce((acc, row) => acc + toNumber(row.amount), 0);

  return (
    <Screen
      title="Purchases"
      eyebrow={
        data ? `${data.meta.total} bills · ${formatMoney(total, { decimals: false })}` : null
      }
      flush
      reserveBottom={80}
      headerExtra={
        <div className="bg-surface/80 px-4 pb-3 backdrop-blur-xl">
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Supplier, bill number or item"
          />
        </div>
      }
    >
      {isLoading ? <SkeletonRows /> : null}

      {data && groups.length === 0 ? (
        <EmptyState
          icon={Inbox}
          title={query ? 'No bills match' : 'No purchases yet'}
          message={
            query
              ? 'Try the supplier name or the number printed on the bill.'
              : 'Record a wholesale bill and it will appear here.'
          }
        />
      ) : null}

      <div className="flex flex-col gap-4 px-4">
        {groups.map((group) => (
          <section key={group.date}>
            <Card padded={false}>
              <GroupHeader
                label={formatRelativeDay(group.date)}
                total={formatMoney(group.total, { decimals: false })}
              />
              {group.rows.map((purchase, index) => (
                <div key={purchase.id}>
                  {index > 0 ? <Divider /> : null}
                  <PurchaseRow purchase={purchase} />
                </div>
              ))}
            </Card>
          </section>
        ))}
      </div>

      <Fab to="/purchases/new" label="New bill" />
    </Screen>
  );
}
