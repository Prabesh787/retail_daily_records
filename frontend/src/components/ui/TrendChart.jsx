import { useState } from 'react';
import { cn } from '@/lib/cn';
import { formatDateAd, formatMoney, formatMoneyShort, toNumber } from '@/lib/format';

/**
 * Daily sales for the last two weeks.
 *
 * Bars rather than a line: each day is a discrete closed total, not a reading
 * off a continuous signal. One series, so no legend — the card heading names
 * it. Only the day in focus is labelled; a number over every bar would be noise
 * at this width. Tap or hover a column for the exact figure.
 */
export function TrendChart({ points = [], height = 92 }) {
  const [active, setActive] = useState(null);

  if (points.length === 0) return null;

  const values = points.map((point) => toNumber(point.amount));
  const max = Math.max(...values, 1);
  const peakIndex = values.indexOf(Math.max(...values));
  const shown = active ?? peakIndex;
  const shownPoint = points[shown];

  return (
    <div className="flex flex-col gap-2">
      <div aria-live="polite" className="flex min-h-[22px] items-baseline gap-2">
        <span className="text-in text-[17px] font-bold tracking-[-0.02em] tabular-nums">
          {formatMoney(shownPoint.amount, { decimals: false })}
        </span>
        <span className="text-ink-subtle text-xs">
          {formatDateAd(shownPoint.date, { withYear: false })}
        </span>
      </div>

      <div
        role="img"
        style={{ height }}
        onPointerLeave={() => setActive(null)}
        aria-label={`Daily sales for the last ${points.length} days. Best day ${formatDateAd(
          points[peakIndex].date,
        )} at ${formatMoney(points[peakIndex].amount)}.`}
        /* 2px of surface between adjacent bars keeps the marks separate. */
        className="flex items-end gap-0.5"
      >
        {points.map((point, index) => {
          const value = toNumber(point.amount);
          // A day with no sales still gets a stub, so a gap reads as "zero"
          // rather than "missing".
          const ratio = value / max;
          return (
            <button
              key={point.date}
              type="button"
              onPointerEnter={() => setActive(index)}
              onClick={() => setActive(index)}
              aria-label={`${formatDateAd(point.date)}: ${formatMoney(point.amount)}`}
              /* The hit target is the whole column, not just the drawn bar. */
              className="group flex h-full flex-1 items-end rounded-lg"
            >
              <span
                style={{ height: `${Math.max(ratio * 100, value > 0 ? 6 : 2)}%` }}
                className={cn(
                  'bg-in ease-out-quart w-full rounded-t transition-[opacity,height] duration-300',
                  index === shown ? 'opacity-100' : 'opacity-40',
                )}
              />
            </button>
          );
        })}
      </div>

      {/* Recessive: the axis is scaffolding, not data. */}
      <div className="text-ink-subtle flex justify-between text-[11px]">
        <span>{formatDateAd(points[0].date, { withYear: false })}</span>
        <span className="tabular-nums">peak {formatMoneyShort(points[peakIndex].amount)}</span>
        <span>{formatDateAd(points.at(-1).date, { withYear: false })}</span>
      </div>
    </div>
  );
}
