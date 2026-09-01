import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Users } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Fab } from '@/components/layout/Fab';
import { Card, Divider, EmptyState, SearchField, SkeletonRows } from '@/components/ui';
import { BalanceCard, SupplierRow } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { toNumber } from '@/lib/format';

/**
 * Suppliers ordered by what is owed, largest first — the list is a payables
 * worklist, not an address book.
 */
export function SuppliersScreen() {
  const [search, setSearch] = useState('');
  const query = useDebouncedValue(search);

  const params = { q: query || undefined, limit: 100 };
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.suppliers(params),
    queryFn: () => api.suppliers.list(params),
  });

  const rows = data?.data ?? [];
  const totals = rows.reduce(
    (acc, row) => ({
      outstanding: acc.outstanding + toNumber(row.balance?.outstanding),
      cleared: acc.cleared + toNumber(row.balance?.clearedTotal),
      uncleared: acc.uncleared + toNumber(row.balance?.unclearedTotal),
    }),
    { outstanding: 0, cleared: 0, uncleared: 0 },
  );

  return (
    <Screen
      title="Suppliers"
      flush
      reserveBottom={80}
      headerExtra={
        <div className="bg-surface/80 px-4 pb-3 backdrop-blur-xl">
          <SearchField value={search} onChange={setSearch} placeholder="Name or phone" />
        </div>
      }
    >
      <div className="px-4 pb-4">
        <BalanceCard
          label="Total payable"
          amount={totals.outstanding}
          cleared={totals.cleared}
          uncleared={totals.uncleared}
          caption={`Across ${rows.length} supplier${rows.length === 1 ? '' : 's'}`}
        />
      </div>

      {isLoading ? <SkeletonRows /> : null}

      {data && rows.length === 0 ? (
        <EmptyState icon={Users} title="No suppliers found" message="Try a different name." />
      ) : null}

      <div className="px-4">
        <Card padded={false}>
          {rows.map((supplier, index) => (
            <div key={supplier.id}>
              {index > 0 ? <Divider /> : null}
              <SupplierRow supplier={supplier} />
            </div>
          ))}
        </Card>
      </div>

      <Fab to="/suppliers/new" label="New supplier" />
    </Screen>
  );
}
