import { formatDateAd } from '@/lib/format';

const iso = (date) => date.toISOString().slice(0, 10);
const shift = (days) => iso(new Date(Date.now() - days * 86400000));

/** Presets first, because a specific day is the rare case, not the common one. */
export function buildPresets(fiscalYear) {
  const now = new Date();
  const monthStart = iso(new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)));

  return [
    { id: 'all', label: 'All time', from: '', to: '' },
    { id: 'today', label: 'Today', from: iso(now), to: iso(now) },
    { id: 'week', label: 'Last 7 days', from: shift(6), to: iso(now) },
    { id: 'month', label: 'This month', from: monthStart, to: iso(now) },
    { id: 'days30', label: 'Last 30 days', from: shift(29), to: iso(now) },
    ...(fiscalYear
      ? [
          {
            id: 'fy',
            label: `FY ${fiscalYear.name}`,
            from: fiscalYear.startDate,
            to: fiscalYear.endDate,
          },
        ]
      : []),
  ];
}

/** The label shown on the trigger button for the current range. */
export function describeRange(range, presets) {
  const match = presets.find((p) => p.from === range.from && p.to === range.to);
  if (match) return match.label;
  if (range.from && range.to) {
    return `${formatDateAd(range.from, { withYear: false })} – ${formatDateAd(range.to)}`;
  }
  if (range.from) return `From ${formatDateAd(range.from)}`;
  if (range.to) return `Until ${formatDateAd(range.to)}`;
  return 'All time';
}
