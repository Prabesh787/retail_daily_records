/**
 * Bikram Sambat <-> Gregorian conversion.
 *
 * The database stores Gregorian (AD) `date` values because Postgres can sort
 * and range-query them, and keeps the BS string the shopkeeper typed alongside
 * for display. Most of the time that BS string arrives from the client, so no
 * conversion is needed. Reports are the exception: "today" and the days in a
 * trend line are produced by the server, and they still have to be shown in
 * the calendar the shop actually works in.
 *
 * BS months have no formula - their length is fixed by an almanac each year -
 * so the only correct implementation is a lookup table. `BS_MONTH_DAYS` below
 * covers BS 2000-2100 (AD 1943-2044), anchored on the one date every published
 * table agrees on:
 *
 *   1 Baishakh 2000 BS = 14 April 1943 AD
 *
 * Conversion walks whole months from that anchor, so a wrong table would show
 * up immediately as a drifting date rather than as a silent off-by-one.
 */

const ANCHOR_BS_YEAR = 2000;
const ANCHOR_AD_UTC = Date.UTC(1943, 3, 14);
const DAY_MS = 86_400_000;

/** Days in each of the 12 BS months, keyed by BS year. */
const BS_MONTH_DAYS = {
  2000: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2001: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2002: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2003: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2004: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2005: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2006: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2007: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2008: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2009: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2010: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2011: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2012: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2013: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2014: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2015: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2016: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2017: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2018: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2019: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2020: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2021: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2022: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2023: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2024: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2025: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2026: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2027: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2028: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2029: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2030: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2031: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2032: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2033: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2034: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2035: [30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2036: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2037: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2038: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2039: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2040: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2041: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2042: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2043: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2044: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2045: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2046: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2047: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2048: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2049: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2050: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2051: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2052: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2053: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2054: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2055: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2056: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2057: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2058: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2059: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2060: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2061: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2062: [31, 31, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
  2063: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2064: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2065: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2066: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2067: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2068: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2069: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2070: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2071: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2072: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2073: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2074: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
  2085: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2086: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2087: [31, 31, 32, 31, 31, 31, 30, 29, 30, 30, 30, 30],
  2088: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2089: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2090: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2091: [31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
  2092: [30, 31, 32, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2093: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2094: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
  2095: [31, 31, 32, 31, 31, 31, 30, 29, 30, 30, 30, 30],
  2096: [30, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2097: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2098: [31, 31, 32, 31, 31, 31, 29, 30, 29, 30, 29, 31],
  2099: [31, 31, 32, 31, 31, 31, 30, 29, 29, 30, 30, 30],
  2100: [31, 32, 31, 32, 30, 31, 30, 29, 30, 29, 30, 30],
};

const BS_YEARS = Object.keys(BS_MONTH_DAYS).map(Number);
const MIN_BS_YEAR = Math.min(...BS_YEARS);
const MAX_BS_YEAR = Math.max(...BS_YEARS);

/** Total days in a BS year, memoised because the trend report calls this a lot. */
const yearLengthCache = new Map();
function bsYearLength(year) {
  let cached = yearLengthCache.get(year);
  if (cached === undefined) {
    cached = BS_MONTH_DAYS[year].reduce((total, days) => total + days, 0);
    yearLengthCache.set(year, cached);
  }
  return cached;
}

/** `YYYY-MM-DD` (or a Date) to UTC midnight, or NaN if it is not a real date. */
function toUtcMidnight(value) {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime())
      ? Number.NaN
      : Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate());
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value ?? ''));
  if (!match) return Number.NaN;
  const [, year, month, day] = match.map(Number);
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);
  // Round-tripping rejects impossible dates such as 2026-02-31.
  return date.getUTCMonth() === month - 1 && date.getUTCDate() === day ? time : Number.NaN;
}

const pad = (value) => String(value).padStart(2, '0');

/**
 * A `Date` (or ISO string) as the plain `YYYY-MM-DD` the API puts on the wire.
 * `@db.Date` columns come back as UTC midnight, so reading the UTC parts is
 * what keeps the day from shifting under a non-UTC server clock.
 *
 * @param {Date | string | null | undefined} value
 * @returns {string | null}
 */
export function toIsoDate(value) {
  const time = toUtcMidnight(value);
  if (Number.isNaN(time)) return null;
  const date = new Date(time);
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

/**
 * Gregorian to Bikram Sambat.
 *
 * @param {Date | string | null | undefined} value AD date, `YYYY-MM-DD` or Date.
 * @returns {string | null} BS date as `YYYY-MM-DD`, or null if out of range.
 */
export function adToBs(value) {
  const time = toUtcMidnight(value);
  if (Number.isNaN(time)) return null;

  let remaining = Math.round((time - ANCHOR_AD_UTC) / DAY_MS);
  if (remaining < 0) return null;

  let year = ANCHOR_BS_YEAR;
  for (;;) {
    if (year > MAX_BS_YEAR) return null;
    const length = bsYearLength(year);
    if (remaining < length) break;
    remaining -= length;
    year += 1;
  }

  let month = 1;
  while (remaining >= BS_MONTH_DAYS[year][month - 1]) {
    remaining -= BS_MONTH_DAYS[year][month - 1];
    month += 1;
  }

  return `${year}-${pad(month)}-${pad(remaining + 1)}`;
}

/**
 * Bikram Sambat to Gregorian. The inverse of `adToBs`, kept beside it so the
 * two can never be anchored on different tables.
 *
 * @param {string | null | undefined} value BS date as `YYYY-MM-DD`.
 * @returns {string | null} AD date as `YYYY-MM-DD`, or null if out of range.
 */
export function bsToAd(value) {
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(String(value ?? '').trim());
  if (!match) return null;

  const [, year, month, day] = match.map(Number);
  if (year < MIN_BS_YEAR || year > MAX_BS_YEAR) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > BS_MONTH_DAYS[year][month - 1]) return null;

  let days = 0;
  for (let y = ANCHOR_BS_YEAR; y < year; y += 1) days += bsYearLength(y);
  for (let m = 1; m < month; m += 1) days += BS_MONTH_DAYS[year][m - 1];
  days += day - 1;

  return toIsoDate(new Date(ANCHOR_AD_UTC + days * DAY_MS));
}

/**
 * Today's calendar date in the shop's timezone, as `YYYY-MM-DD`.
 *
 * A dashboard must not roll over at UTC midnight: Kathmandu is UTC+05:45, so
 * a UTC-derived "today" would still be showing yesterday's takings until a
 * quarter past six in the morning, every morning.
 *
 * @param {string} timeZone IANA zone, e.g. "Asia/Kathmandu".
 */
export function todayInTimeZone(timeZone) {
  // en-CA formats as YYYY-MM-DD, which is exactly the wire format.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

/**
 * Turns a `YYYY-MM-DD` string into the UTC-midnight `Date` that `@db.Date`
 * columns are compared against.
 *
 * @param {string} isoDate
 */
export function toDbDate(isoDate) {
  const time = toUtcMidnight(isoDate);
  return Number.isNaN(time) ? null : new Date(time);
}

/**
 * `count` consecutive `YYYY-MM-DD` days ending on `endIsoDate`, oldest first -
 * the x-axis of the dashboard trend chart.
 *
 * @param {string} endIsoDate
 * @param {number} count
 */
export function isoDaysEndingOn(endIsoDate, count) {
  const end = toUtcMidnight(endIsoDate);
  if (Number.isNaN(end)) return [];
  const days = [];
  for (let offset = count - 1; offset >= 0; offset -= 1) {
    days.push(toIsoDate(new Date(end - offset * DAY_MS)));
  }
  return days;
}

/**
 * `isoDate` shifted by whole days, e.g. `addDays(today, -29)` for a 30 day
 * window that includes today.
 *
 * @param {string} isoDate
 * @param {number} days
 */
export function addDays(isoDate, days) {
  const time = toUtcMidnight(isoDate);
  return Number.isNaN(time) ? null : toIsoDate(new Date(time + days * DAY_MS));
}
