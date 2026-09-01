import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { UserRound } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Fab } from '@/components/layout/Fab';
import {
  Avatar,
  Card,
  Divider,
  EmptyState,
  ListRow,
  RowAmount,
  SearchField,
  SkeletonRows,
} from '@/components/ui';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { formatMoney } from '@/lib/format';

/** Customers are optional in this system — most sales are walk-in and carry none. */
export function CustomersScreen() {
  const [search, setSearch] = useState('');
  const query = useDebouncedValue(search);

  const params = { q: query || undefined, limit: 100 };
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.customers(params),
    queryFn: () => api.customers.list(params),
  });

  const rows = data?.data ?? [];

  return (
    <Screen
      title="Customers"
      back
      flush
      reserveBottom={80}
      headerExtra={
        <div className="bg-surface/80 px-4 pb-3 backdrop-blur-xl">
          <SearchField value={search} onChange={setSearch} placeholder="Name or phone" />
        </div>
      }
    >
      {isLoading ? <SkeletonRows /> : null}

      {data && rows.length === 0 ? (
        <EmptyState
          icon={UserRound}
          title="No customers found"
          message="Only customers who asked for an invoice are recorded here."
        />
      ) : null}

      <div className="px-4">
        <Card padded={false}>
          {rows.map((customer, index) => (
            <div key={customer.id}>
              {index > 0 ? <Divider /> : null}
              <ListRow
                leading={<Avatar name={customer.name} />}
                title={customer.name}
                subtitle={[customer.phone, customer.address].filter(Boolean).join(' · ')}
                trailing={
                  <>
                    <RowAmount tone="in">
                      {formatMoney(customer.saleTotal, { decimals: false })}
                    </RowAmount>
                    <span className="text-ink-subtle text-[11.5px]">
                      {customer.saleCount} invoice{customer.saleCount === 1 ? '' : 's'}
                    </span>
                  </>
                }
              />
            </div>
          ))}
        </Card>
      </div>

      <Fab to="/customers/new" label="New customer" />
    </Screen>
  );
}
