/**
 * Display formatting. Every amount on the wire is a decimal *string* (the API
 * never sends floats), so each helper takes a string or a number and is safe
 * against `null`.
 */

/** Nepali/Indian digit grouping: 12,34,567.00 rather than 1,234,567.00. */
const npr = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const nprCompact = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

export function toNumber(value) {
  if (value === null || value === undefined || value === '') return 0;
  const n = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(n) ? n : 0;
}

/** `formatMoney('100000')` → `"Rs 1,00,000.00"` */
export function formatMoney(value, { symbol = true, decimals = true } = {}) {
  const n = toNumber(value);
  const body = decimals ? npr.format(n) : nprCompact.format(n);
  return symbol ? `Rs ${body}` : body;
}

/** Short form for tiles where the column is narrow: 1.2L, 45.5K. */
export function formatMoneyShort(value, { symbol = true } = {}) {
  const n = toNumber(value);
  const abs = Math.abs(n);
  const sign = n < 0 ? '-' : '';
  let body;
  if (abs >= 1e7) body = `${(abs / 1e7).toFixed(2)}Cr`;
  else if (abs >= 1e5) body = `${(abs / 1e5).toFixed(2)}L`;
  else if (abs >= 1000) body = `${(abs / 1000).toFixed(1)}K`;
  else body = nprCompact.format(abs);
  return `${symbol ? 'Rs ' : ''}${sign}${body}`;
}

export function formatQuantity(value) {
  const n = toNumber(value);
  return Number.isInteger(n) ? String(n) : n.toFixed(3).replace(/0+$/, '').replace(/\.$/, '');
}

const AD_MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const BS_MONTHS = [
  'Baishakh',
  'Jestha',
  'Ashadh',
  'Shrawan',
  'Bhadra',
  'Ashwin',
  'Kartik',
  'Mangsir',
  'Poush',
  'Magh',
  'Falgun',
  'Chaitra',
];

/** ISO or Date → `"10 Aug 2026"`. */
export function formatDateAd(value, { withYear = true } = {}) {
  if (!value) return '—';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  const day = String(d.getUTCDate()).padStart(2, '0');
  const month = AD_MONTHS[d.getUTCMonth()];
  return withYear ? `${day} ${month} ${d.getUTCFullYear()}` : `${day} ${month}`;
}

/**
 * BS dates arrive as plain `YYYY-MM-DD` strings the shopkeeper typed. We only
 * ever display them — converting between calendars is out of scope here.
 */
export function formatDateBs(value, { long = false } = {}) {
  if (!value) return null;
  const [y, m, d] = String(value).split('-');
  if (!y || !m || !d) return value;
  const monthIndex = Number(m) - 1;
  if (!long) return `${d}/${m}/${y} BS`;
  return `${Number(d)} ${BS_MONTHS[monthIndex] ?? m} ${y}`;
}

/**
 * The date line used on every record row: BS first because that is what the
 * shop works in, AD in brackets because that is what the paperwork prints.
 */
export function formatDatePair(ad, bs) {
  const bsText = formatDateBs(bs);
  const adText = formatDateAd(ad);
  return bsText ? `${bsText} · ${adText}` : adText;
}

/** `"2026-09-01T09:40:00Z"` → `"9:40 am"`. Several sales now share a date. */
export function formatTime(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d
    .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
    .toLowerCase();
}

/** "Today", "Yesterday", "3 days ago", then an absolute date. */
export function formatRelativeDay(value) {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  const startOf = (x) => Date.UTC(x.getUTCFullYear(), x.getUTCMonth(), x.getUTCDate());
  const days = Math.round((startOf(new Date()) - startOf(d)) / 86400000);
  if (days === 0) return 'Today';
  if (days === 1) return 'Yesterday';
  if (days === -1) return 'Tomorrow';
  if (days > 1 && days < 7) return `${days} days ago`;
  if (days < -1 && days > -14) return `in ${Math.abs(days)} days`;
  return formatDateAd(d);
}

/** Days until a future-dated cheque falls due. Negative means overdue. */
export function daysUntil(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  const startOf = (x) => Date.UTC(x.getUTCFullYear(), x.getUTCMonth(), x.getUTCDate());
  return Math.round((startOf(d) - startOf(new Date())) / 86400000);
}

/** "ABC Textile Suppliers" → "AT", for the list avatars. */
export function initials(name = '') {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0]?.toUpperCase() ?? '')
    .join('');
}

/** Stable pastel per name, so the same supplier keeps the same avatar colour. */
export function colorFromString(value = '') {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) hash = (hash * 31 + value.charCodeAt(i)) % 360;
  return hash;
}

export function todayIso() {
  return new Date().toISOString().slice(0, 10);
}
