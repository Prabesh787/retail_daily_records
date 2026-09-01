import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';
import { Avatar, Badge, ListRow, RowAmount } from '@/components/ui';
import { formatDatePair, formatMoney, formatRelativeDay, formatTime } from '@/lib/format';
import { SALE_PAYMENT_MODE, SALE_TYPE } from '@/lib/constants';
import { PaymentModeBadge, PaymentStatusBadge } from './StatusBadge';

export function PurchaseRow({ purchase }) {
  return (
    <ListRow
      as={Link}
      to={`/purchases/${purchase.id}`}
      leading={<Avatar name={purchase.supplier?.name ?? '?'} />}
      title={purchase.supplier?.name ?? 'Unknown supplier'}
      subtitle={`Bill ${purchase.billNo} · ${formatDatePair(purchase.billDate, purchase.billDateBs)}`}
      trailing={
        <RowAmount tone="out">{formatMoney(purchase.amount, { decimals: false })}</RowAmount>
      }
      chevron
    />
  );
}

export function SaleRow({ sale, showDate = false }) {
  const isItemised = sale.saleType === 'DETAILED';
  const mode = sale.payments?.[0]?.paymentMode;
  const onCredit = mode === 'CREDIT';

  // Several sales share a date now, so the second line carries the time rather
  // than repeating the day.
  const when = showDate
    ? formatDatePair(sale.saleDate, sale.saleDateBs)
    : formatTime(sale.createdAt);

  return (
    <ListRow
      as={Link}
      to={`/sales/${sale.id}`}
      leading={<Avatar name={sale.customer?.name ?? sale.description ?? 'Walk-in'} />}
      title={sale.customer?.name ?? 'Walk-in customer'}
      subtitle={[
        when,
        isItemised
          ? `Invoice ${sale.invoiceNo} · ${sale.items?.length ?? 0} item${sale.items?.length === 1 ? '' : 's'}`
          : sale.description,
      ]
        .filter(Boolean)
        .join(' · ')}
      trailing={
        <>
          <RowAmount tone={onCredit ? 'pending' : 'in'}>
            {formatMoney(sale.totalAmount, { decimals: false })}
          </RowAmount>
          {onCredit ? (
            <Badge tone="warning">Credit</Badge>
          ) : (
            <span className="text-ink-subtle text-[11.5px]">
              {SALE_PAYMENT_MODE[mode]?.label ?? SALE_TYPE[sale.saleType].label}
            </span>
          )}
        </>
      }
      chevron
    />
  );
}

export function SupplierRow({ supplier }) {
  const outstanding = Number(supplier.balance?.outstanding ?? 0);
  return (
    <ListRow
      as={Link}
      to={`/suppliers/${supplier.id}`}
      leading={<Avatar name={supplier.name} />}
      title={supplier.name}
      subtitle={supplier.phone ? `${supplier.phone} · ${supplier.address ?? ''}` : supplier.address}
      trailing={
        <>
          <RowAmount tone={outstanding > 0 ? 'out' : undefined}>
            {outstanding > 0 ? formatMoney(outstanding, { decimals: false }) : 'Settled'}
          </RowAmount>
          <span className="t-caption">{supplier.balance?.billCount ?? 0} bills</span>
        </>
      }
      chevron
    />
  );
}

export function PaymentRow({ payment, showSupplier = true }) {
  return (
    <ListRow
      as={Link}
      to={`/payments/${payment.id}`}
      leading={<Avatar name={payment.supplier?.name ?? 'Payment'} />}
      title={showSupplier ? (payment.supplier?.name ?? 'Payment') : `Voucher ${payment.voucherNo}`}
      subtitle={[
        payment.paymentMode === 'CHEQUE'
          ? `Cheque ${payment.chequeNo} · dated ${formatRelativeDay(payment.chequeDate)}`
          : formatDatePair(payment.paymentDate, payment.paymentDateBs),
        // Which bill this settles, when it settles a specific one.
        payment.purchase ? `Bill ${payment.purchase.billNo}` : null,
      ]
        .filter(Boolean)
        .join(' · ')}
      trailing={
        <>
          <RowAmount>{formatMoney(payment.amount, { decimals: false })}</RowAmount>
          <PaymentStatusBadge status={payment.status} />
        </>
      }
      chevron
    />
  );
}

export function ChequeRow({ payment, dueLabel }) {
  return (
    <ListRow
      as={Link}
      to={`/payments/${payment.id}`}
      leading={<Avatar name={payment.supplier?.name ?? 'Cheque'} />}
      title={payment.supplier?.name ?? 'Cheque'}
      subtitle={`No. ${payment.chequeNo} · ${formatDatePair(payment.chequeDate, payment.chequeDateBs)}`}
      trailing={
        <>
          <RowAmount>{formatMoney(payment.amount, { decimals: false })}</RowAmount>
          {dueLabel ? (
            <span className="text-pending text-[11.5px] font-semibold tabular-nums">
              {dueLabel}
            </span>
          ) : null}
        </>
      }
      chevron
    />
  );
}

/**
 * Sticky date separator inside a grouped list. When `to` is given the whole
 * header is a link into that day's own record.
 */
export function GroupHeader({ label, total, count, to }) {
  const Tag = to ? Link : 'div';
  return (
    <Tag
      to={to}
      className="bg-sunken text-ink-subtle sticky top-0 z-5 flex items-center justify-between px-4 py-[7px] text-[11.5px] font-bold tracking-[0.05em] uppercase"
    >
      <span className="flex items-center gap-1.5">
        {label}
        {count ? (
          <span className="text-ink-subtle font-semibold normal-case">
            · {count} sale{count === 1 ? '' : 's'}
          </span>
        ) : null}
      </span>
      <span className="flex items-center gap-1">
        {total ? (
          <span className="text-[11.5px] font-semibold tracking-normal normal-case tabular-nums">
            {total}
          </span>
        ) : null}
        {to ? <ChevronRight size={13} /> : null}
      </span>
    </Tag>
  );
}

export { PaymentModeBadge, PaymentStatusBadge };
