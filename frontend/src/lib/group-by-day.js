import { toNumber } from './format';

/**
 * Splits an already date-sorted list into day buckets with a running total.
 * Both the purchases and the sales lists are read day by day, so the grouping
 * lives here rather than in either screen.
 */
export function groupByDay(rows, dateKey, amountKey) {
  const buckets = new Map();

  for (const row of rows) {
    const date = row[dateKey];
    if (!buckets.has(date)) buckets.set(date, { date, rows: [], total: 0 });
    const bucket = buckets.get(date);
    bucket.rows.push(row);
    bucket.total += toNumber(row[amountKey]);
  }

  return [...buckets.values()];
}
