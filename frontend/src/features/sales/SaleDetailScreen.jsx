import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { Screen } from '@/components/layout/Screen';
import { Card, Divider, SectionHeader, Skeleton } from '@/components/ui';
import { DetailList, PaymentModeBadge, PaymentStatusBadge } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { SALE_TYPE } from '@/lib/constants';
import { formatDateAd, formatDateBs, formatMoney, formatQuantity, toNumber } from '@/lib/format';

export function SaleDetailScreen() {
  const { id } = useParams();
  const { data: sale, isLoading } = useQuery({
    queryKey: queryKeys.sale(id),
    queryFn: () => api.sales.get(id),
  });

  if (isLoading || !sale) {
    return (
      <Screen title="Sale" back>
        <div className="flex flex-col gap-3">
          <Skeleton className="rounded-card h-32" />
          <Skeleton className="rounded-card h-56" />
        </div>
      </Screen>
    );
  }

  const isInvoice = sale.saleType === 'DETAILED';

  return (
    <Screen
      title={isInvoice ? `Invoice ${sale.invoiceNo}` : "Day's takings"}
      eyebrow={sale.customer?.name ?? SALE_TYPE[sale.saleType].label}
      back
    >
      <div className="flex flex-col gap-4">
        <Card>
          <p className="label-section">Total</p>
          <p className="text-in text-[30px] font-bold tracking-[-0.035em] tabular-nums">
            {formatMoney(sale.totalAmount)}
          </p>
          {toNumber(sale.discount) > 0 ? (
            <p className="text-ink-subtle text-[11.5px]">
              {formatMoney(sale.subtotal, { decimals: false })} less{' '}
              {formatMoney(sale.discount, { decimals: false })} discount
            </p>
          ) : null}
        </Card>

        {isInvoice ? (
          <section>
            <SectionHeader title={`Items (${sale.items.length})`} />
            <Card padded={false}>
              {sale.items.map((item, index) => (
                <div key={item.id}>
                  {index > 0 ? <Divider /> : null}
                  <div className="flex items-start justify-between gap-3 px-4 py-3">
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-semibold">{item.description}</span>
                      <span className="text-ink-muted block text-xs tabular-nums">
                        {formatQuantity(item.quantity)} {item.unit} ×{' '}
                        {formatMoney(item.unitPrice, { decimals: false })}
                        {toNumber(item.discount) > 0
                          ? ` − ${formatMoney(item.discount, { decimals: false })}`
                          : ''}
                      </span>
                    </span>
                    <span className="shrink-0 text-sm font-bold tabular-nums">
                      {formatMoney(item.amount, { decimals: false })}
                    </span>
                  </div>
                </div>
              ))}
            </Card>
          </section>
        ) : null}

        <section>
          <SectionHeader title="Settled with" />
          <Card padded={false}>
            {sale.payments.map((payment, index) => (
              <div key={payment.id}>
                {index > 0 ? <Divider /> : null}
                <div className="flex items-center justify-between gap-3 px-4 py-3">
                  <span className="flex items-center gap-2">
                    <PaymentModeBadge mode={payment.paymentMode} kind="sale" />
                    {payment.paymentMode === 'CREDIT' ? (
                      <PaymentStatusBadge status={payment.status} />
                    ) : null}
                  </span>
                  <span className="text-sm font-bold tabular-nums">
                    {formatMoney(payment.amount, { decimals: false })}
                  </span>
                </div>
              </div>
            ))}
          </Card>
        </section>

        <DetailList
          rows={[
            { label: 'Type', value: SALE_TYPE[sale.saleType].label },
            { label: 'Invoice no.', value: sale.invoiceNo, mono: true },
            { label: 'Customer', value: sale.customer?.name ?? 'Walk-in' },
            {
              label: 'Date',
              value: (
                <>
                  {formatDateBs(sale.saleDateBs, { long: true })}
                  <span className="text-ink-subtle block text-xs">
                    {formatDateAd(sale.saleDate)}
                  </span>
                </>
              ),
            },
            { label: 'Description', value: sale.description },
            { label: 'Remarks', value: sale.remarks },
          ]}
        />
      </div>
    </Screen>
  );
}
