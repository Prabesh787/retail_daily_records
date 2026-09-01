import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { ArrowDownLeft, Receipt } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Card, Divider, EmptyState, SectionHeader, Skeleton, StatTile } from '@/components/ui';
import { PurchaseRow, SaleRow } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { SALE_PAYMENT_MODE } from '@/lib/constants';
import { formatDateAd, formatDateBs, formatMoney, formatRelativeDay } from '@/lib/format';

/**
 * One day's record: every sale made that day, what the takings were, and how
 * they were settled. The day total is the sum of the sales listed underneath —
 * there is no separate "day's takings" row anywhere in the system.
 */
export function SaleDayScreen() {
  const { date } = useParams();

  const { data, isLoading } = useQuery({
    queryKey: queryKeys.dayBook(date),
    queryFn: () => api.sales.dayBook(date),
  });

  if (isLoading || !data) {
    return (
      <Screen title="Day" back>
        <div className="flex flex-col gap-3">
          <Skeleton className="rounded-card h-28" />
          <Skeleton className="rounded-card h-56" />
        </div>
      </Screen>
    );
  }

  const modes = Object.entries(data.totals.byMode ?? {});

  return (
    <Screen
      title={formatRelativeDay(date)}
      eyebrow={formatDateBs(data.dateBs, { long: true }) ?? formatDateAd(date)}
      back
    >
      <div className="flex flex-col gap-4">
        <Card>
          <p className="label-section">Takings</p>
          <p className="text-in text-[30px] font-bold tracking-[-0.035em] tabular-nums">
            {formatMoney(data.totals.sales)}
          </p>
          <p className="text-ink-subtle text-[11.5px]">
            From {data.totals.saleCount} sale{data.totals.saleCount === 1 ? '' : 's'}
          </p>

          {modes.length > 0 ? (
            <div className="border-line mt-3 flex flex-wrap gap-x-6 gap-y-3 border-t pt-3">
              {modes.map(([mode, amount]) => (
                <span key={mode} className="text-ink-muted text-xs">
                  {SALE_PAYMENT_MODE[mode]?.label ?? mode}
                  <strong
                    className={`mt-px block text-[15px] font-semibold tabular-nums ${
                      mode === 'CREDIT' ? 'text-pending' : 'text-ink'
                    }`}
                  >
                    {formatMoney(amount, { decimals: false })}
                  </strong>
                </span>
              ))}
            </div>
          ) : null}
        </Card>

        <section>
          <SectionHeader title={`Sales (${data.sales.length})`} />
          {data.sales.length === 0 ? (
            <Card>
              <EmptyState
                icon={Receipt}
                title="No sales on this day"
                message="Nothing was recorded against this date."
              />
            </Card>
          ) : (
            <Card padded={false}>
              {data.sales.map((sale, index) => (
                <div key={sale.id}>
                  {index > 0 ? <Divider /> : null}
                  <SaleRow sale={sale} />
                </div>
              ))}
            </Card>
          )}
        </section>

        {data.purchases.length > 0 ? (
          <section>
            <SectionHeader title="Bills received the same day" />
            <Card padded={false}>
              {data.purchases.map((purchase, index) => (
                <div key={purchase.id}>
                  {index > 0 ? <Divider /> : null}
                  <PurchaseRow purchase={purchase} />
                </div>
              ))}
            </Card>
          </section>
        ) : null}

        {data.payments.length > 0 ? (
          <StatTile
            icon={ArrowDownLeft}
            label="Paid out to suppliers"
            value={formatMoney(data.totals.payments, { decimals: false })}
            foot={`${data.payments.length} payment${data.payments.length === 1 ? '' : 's'}`}
            tone="out"
          />
        ) : null}
      </div>
    </Screen>
  );
}
