import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Banknote, ChevronRight, FileText, Paperclip } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Avatar, Button, Card, Divider, SectionHeader, Skeleton } from '@/components/ui';
import { DetailList, PaymentModeBadge, PaymentStatusBadge } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { formatDateAd, formatDateBs, formatMoney, toNumber } from '@/lib/format';

export function PurchaseDetailScreen() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { data: purchase, isLoading } = useQuery({
    queryKey: queryKeys.purchase(id),
    queryFn: () => api.purchases.get(id),
  });

  if (isLoading || !purchase) {
    return (
      <Screen title="Bill" back>
        <div className="flex flex-col gap-3">
          <Skeleton className="rounded-card h-32" />
          <Skeleton className="rounded-card h-48" />
        </div>
      </Screen>
    );
  }

  const due = toNumber(purchase.dueTotal);

  return (
    <Screen title={`Bill ${purchase.billNo}`} eyebrow={purchase.supplier?.name} back>
      <div className="flex flex-col gap-4">
        {/* The amount is the headline; how much of it is still owed is the
            second thing anyone wants to know. */}
        <Card>
          <p className="label-section">Bill amount</p>
          <p className="text-[30px] font-bold tracking-[-0.035em] tabular-nums">
            {formatMoney(purchase.amount)}
          </p>
          <div className="border-line mt-3 flex gap-6 border-t pt-3">
            <span className="text-ink-muted text-xs">
              Paid
              <strong className="text-in mt-px block text-[15px] font-semibold tabular-nums">
                {formatMoney(purchase.paidTotal, { decimals: false })}
              </strong>
            </span>
            <span className="text-ink-muted text-xs">
              Still owed
              <strong
                className={`mt-px block text-[15px] font-semibold tabular-nums ${due > 0 ? 'text-out' : 'text-in'}`}
              >
                {due > 0 ? formatMoney(due, { decimals: false }) : 'Settled'}
              </strong>
            </span>
          </div>
        </Card>

        <Link to={`/suppliers/${purchase.supplierId}`}>
          <Card padded={false} interactive>
            <div className="flex items-center gap-3 p-4">
              <Avatar name={purchase.supplier?.name ?? '?'} />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14.5px] font-semibold">
                  {purchase.supplier?.name}
                </span>
                <span className="text-ink-muted block truncate text-[12.5px]">
                  {purchase.supplier?.phone ?? purchase.supplier?.address ?? 'Supplier'}
                </span>
              </span>
              <ChevronRight size={17} className="text-ink-subtle" />
            </div>
          </Card>
        </Link>

        <DetailList
          rows={[
            { label: 'Bill number', value: purchase.billNo, mono: true },
            {
              label: 'Bill date',
              value: (
                <>
                  {formatDateBs(purchase.billDateBs, { long: true })}
                  <span className="text-ink-subtle block text-xs">
                    {formatDateAd(purchase.billDate)}
                  </span>
                </>
              ),
            },
            { label: 'Goods', value: purchase.description },
            { label: 'Remarks', value: purchase.remarks },
          ]}
        />

        <section>
          <SectionHeader title={`Payments (${purchase.payments.length})`} />
          <Card padded={false}>
            {purchase.payments.length === 0 ? (
              <p className="text-ink-muted p-4 text-[13.5px]">
                Nothing paid against this bill — it is open credit in full.
              </p>
            ) : (
              purchase.payments.map((payment, index) => (
                <div key={payment.id}>
                  {index > 0 ? <Divider /> : null}
                  <Link
                    to={`/payments/${payment.id}`}
                    className="active:bg-sunken flex items-center gap-3 px-4 py-3"
                  >
                    <span className="bg-sunken text-ink-muted grid size-9 shrink-0 place-items-center rounded-xl">
                      <Banknote size={17} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-semibold tabular-nums">
                        {formatMoney(payment.amount, { decimals: false })}
                      </span>
                      <span className="text-ink-muted block truncate text-xs">
                        {formatDateAd(payment.paymentDate)}
                        {payment.chequeNo ? ` · cheque ${payment.chequeNo}` : ''}
                      </span>
                    </span>
                    <span className="flex shrink-0 flex-col items-end gap-1">
                      <PaymentModeBadge mode={payment.paymentMode} />
                      <PaymentStatusBadge status={payment.status} />
                    </span>
                  </Link>
                </div>
              ))
            )}
          </Card>
        </section>

        {purchase.attachments?.length ? (
          <section>
            <SectionHeader title="Scanned bill" />
            <Card padded={false}>
              {purchase.attachments.map((file, index) => (
                <div key={file.id}>
                  {index > 0 ? <Divider /> : null}
                  <div className="flex items-center gap-3 px-4 py-3">
                    <span className="bg-info-soft text-info grid size-9 shrink-0 place-items-center rounded-xl">
                      <FileText size={17} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium">
                        {file.originalFileName}
                      </span>
                      <span className="text-ink-subtle block text-xs">
                        {Math.round(file.fileSize / 1024)} KB
                      </span>
                    </span>
                  </div>
                </div>
              ))}
            </Card>
          </section>
        ) : null}

        <div className="grid grid-cols-2 gap-3">
          <Button variant="secondary" icon={Paperclip}>
            Attach scan
          </Button>
          <Button
            icon={Banknote}
            onClick={() =>
              navigate(`/payments/new?supplierId=${purchase.supplierId}&purchaseId=${purchase.id}`)
            }
          >
            Record payment
          </Button>
        </div>
      </div>
    </Screen>
  );
}
