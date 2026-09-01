import { Badge } from '@/components/ui';
import { PAYMENT_STATUS, SALE_PAYMENT_MODE, SUPPLIER_PAYMENT_MODE } from '@/lib/constants';

export function PaymentStatusBadge({ status }) {
  const meta = PAYMENT_STATUS[status];
  if (!meta) return null;
  return <Badge tone={meta.tone}>{meta.label}</Badge>;
}

export function PaymentModeBadge({ mode, kind = 'supplier' }) {
  const table = kind === 'sale' ? SALE_PAYMENT_MODE : SUPPLIER_PAYMENT_MODE;
  const meta = table[mode];
  if (!meta) return null;
  return (
    <Badge tone={meta.tone} dot={false}>
      {meta.label}
    </Badge>
  );
}
