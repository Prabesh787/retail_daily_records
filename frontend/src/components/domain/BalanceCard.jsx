import { formatMoney } from '@/lib/format';

/**
 * The headline figure on the supplier screens: what the shop still owes.
 * The split underneath is the whole point — money already gone is not the same
 * thing as a cheque that has been handed over but not yet presented.
 */
export function BalanceCard({ label = 'You owe', amount, cleared, uncleared, caption }) {
  return (
    <div className="shadow-lift from-brand relative overflow-hidden rounded-[28px] bg-linear-145 to-[#24216e] p-5 text-white">
      {/* Soft highlight, so the card is not a flat block of colour. */}
      <span aria-hidden className="absolute -top-15 -right-10 size-45 rounded-full bg-white/10" />
      <span className="text-xs font-semibold tracking-[0.04em] uppercase opacity-75">{label}</span>
      <div className="mt-0.5 text-[32px] font-bold tracking-[-0.035em] tabular-nums">
        {formatMoney(amount)}
      </div>
      {caption ? <span className="text-xs opacity-80">{caption}</span> : null}

      {cleared !== undefined ? (
        <div className="relative mt-4 flex gap-5 border-t border-white/20 pt-4">
          <span className="text-xs opacity-80">
            Paid &amp; cleared
            <strong className="mt-px block text-[15px] font-semibold tabular-nums opacity-100">
              {formatMoney(cleared, { decimals: false })}
            </strong>
          </span>
          <span className="text-xs opacity-80">
            Cheques not cleared
            <strong className="mt-px block text-[15px] font-semibold tabular-nums opacity-100">
              {formatMoney(uncleared, { decimals: false })}
            </strong>
          </span>
        </div>
      ) : null}
    </div>
  );
}
