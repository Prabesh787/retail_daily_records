import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { Check, Ban } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Button, Card, Skeleton, useToast } from '@/components/ui';
import { DetailList, PaymentModeBadge, PaymentStatusBadge } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { PAYMENT_STATUS } from '@/lib/constants';
import { formatDateAd, formatDateBs, formatMoney, todayIso } from '@/lib/format';

export function PaymentDetailScreen() {
  const { id } = useParams();
  const toast = useToast();
  const queryClient = useQueryClient();

  const { data: payment, isLoading } = useQuery({
    queryKey: queryKeys.payment(id),
    queryFn: () => api.supplierPayments.get(id),
  });

  /** Clearing or cancelling changes what the shop owes, so the derived
      balances everywhere else have to be refetched. */
  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.payment(id) });
    queryClient.invalidateQueries({ queryKey: ['supplier-payments'] });
    queryClient.invalidateQueries({ queryKey: ['cheque-register'] });
    queryClient.invalidateQueries({ queryKey: ['suppliers'] });
    queryClient.invalidateQueries({ queryKey: ['supplier'] });
    queryClient.invalidateQueries({ queryKey: ['dashboard'] });
  };

  const clear = useMutation({
    mutationFn: () => api.supplierPayments.clear(id, { clearedDate: todayIso() }),
    onSuccess: () => {
      invalidate();
      toast.success('Marked as cleared');
    },
    onError: (error) => toast.error(error.message),
  });

  const cancel = useMutation({
    mutationFn: () => api.supplierPayments.cancel(id),
    onSuccess: () => {
      invalidate();
      toast.success('Payment cancelled');
    },
    onError: (error) => toast.error(error.message),
  });

  if (isLoading || !payment) {
    return (
      <Screen title="Payment" back>
        <Skeleton className="rounded-card h-40" />
      </Screen>
    );
  }

  const isCheque = payment.paymentMode === 'CHEQUE';

  return (
    <Screen title="Payment" eyebrow={payment.supplier?.name} back>
      <div className="flex flex-col gap-4">
        <Card>
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="label-section">Amount</p>
              <p className="text-[30px] font-bold tracking-[-0.035em] tabular-nums">
                {formatMoney(payment.amount)}
              </p>
              <p className="text-ink-subtle text-[11.5px]">{PAYMENT_STATUS[payment.status].hint}</p>
            </div>
            <div className="flex flex-col items-end gap-1.5">
              <PaymentModeBadge mode={payment.paymentMode} />
              <PaymentStatusBadge status={payment.status} />
            </div>
          </div>
        </Card>

        <DetailList
          rows={[
            { label: 'Voucher no.', value: payment.voucherNo, mono: true },
            {
              label: 'Paid on',
              value: (
                <>
                  {formatDateBs(payment.paymentDateBs, { long: true })}
                  <span className="text-ink-subtle block text-xs">
                    {formatDateAd(payment.paymentDate)}
                  </span>
                </>
              ),
            },
            { label: 'Cheque no.', value: payment.chequeNo, mono: true },
            {
              label: 'Cheque dated',
              value: payment.chequeDate ? formatDateAd(payment.chequeDate) : null,
            },
            {
              label: 'Cleared on',
              value: payment.clearedDate ? formatDateAd(payment.clearedDate) : null,
            },
            { label: 'Reference', value: payment.referenceNo, mono: true },
            {
              label: 'Against bill',
              value: payment.purchase ? `Bill ${payment.purchase.billNo}` : null,
            },
            { label: 'Note', value: payment.description },
          ]}
        />

        {payment.status === 'ISSUED' ? (
          <div className="flex flex-col gap-3">
            <Button
              icon={Check}
              size="lg"
              block
              loading={clear.isPending}
              onClick={() => clear.mutate()}
            >
              {isCheque ? 'Cheque has cleared' : 'Mark as cleared'}
            </Button>
            <Button
              variant="secondary"
              icon={Ban}
              block
              loading={cancel.isPending}
              onClick={() => cancel.mutate()}
            >
              Cancel this payment
            </Button>
          </div>
        ) : null}
      </div>
    </Screen>
  );
}
