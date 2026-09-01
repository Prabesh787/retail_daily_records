/**
 * Approximate AD → BS conversion, used only to give the mock fixtures a
 * plausible `*_dateBs` string.
 *
 * A correct conversion needs the full month-length table for every BS year;
 * the real app takes the BS date from the shopkeeper's input (or a dedicated
 * converter) and the API stores it verbatim, so nothing here ships to
 * production. The anchors below cover the window the fixtures span.
 */

/** First AD day of each listed BS month. */
const MONTH_STARTS = [
  ['2082-09-01', '2025-12-16'],
  ['2082-10-01', '2026-01-15'],
  ['2082-11-01', '2026-02-13'],
  ['2082-12-01', '2026-03-15'],
  ['2083-01-01', '2026-04-14'],
  ['2083-02-01', '2026-05-15'],
  ['2083-03-01', '2026-06-15'],
  ['2083-04-01', '2026-07-17'],
  ['2083-05-01', '2026-08-17'],
  ['2083-06-01', '2026-09-17'],
  ['2083-07-01', '2026-10-18'],
  ['2083-08-01', '2026-11-17'],
  ['2083-09-01', '2026-12-16'],
  ['2083-10-01', '2027-01-15'],
].map(([bs, ad]) => ({ bs, adTime: Date.parse(`${ad}T00:00:00Z`) }));

const DAY = 86400000;

export function adToBs(isoDate) {
  if (!isoDate) return null;
  const time = Date.parse(`${String(isoDate).slice(0, 10)}T00:00:00Z`);
  if (Number.isNaN(time)) return null;

  // Latest anchor that is not after the date.
  let anchor = null;
  for (const candidate of MONTH_STARTS) {
    if (candidate.adTime <= time) anchor = candidate;
    else break;
  }
  if (!anchor) return null;

  const dayOfMonth = Math.round((time - anchor.adTime) / DAY) + 1;
  const [year, month] = anchor.bs.split('-');
  return `${year}-${month}-${String(dayOfMonth).padStart(2, '0')}`;
}
