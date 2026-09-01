import { Prisma } from '../../database/generated/prisma/index.js';

/**
 * All money in this system is `numeric(14,2)` and all quantities are
 * `numeric(14,3)`. Arithmetic goes through Prisma's Decimal so rounding is
 * predictable; plain JavaScript numbers only appear at the edges (JSON in,
 * JSON out).
 */
export const Decimal = Prisma.Decimal;

export const MONEY_DP = 2;
export const QUANTITY_DP = 3;

/** @param {string | number | Prisma.Decimal} value */
export function toMoney(value) {
  return new Decimal(value).toDecimalPlaces(MONEY_DP, Decimal.ROUND_HALF_UP);
}

/** @param {string | number | Prisma.Decimal} value */
export function toQuantity(value) {
  return new Decimal(value).toDecimalPlaces(QUANTITY_DP, Decimal.ROUND_HALF_UP);
}

/**
 * Amount of a single detailed-sale invoice line. Always recomputed here; the
 * value a client sends for `amount` is ignored on purpose.
 *
 * @param {string | number} quantity
 * @param {string | number} unitPrice
 * @param {string | number} [discount]
 */
export function calculateLineAmount(quantity, unitPrice, discount = 0) {
  return toMoney(toQuantity(quantity).times(unitPrice).minus(discount));
}

/** @param {Array<string | number | Prisma.Decimal>} values */
export function sumMoney(values) {
  return values.reduce((acc, value) => acc.plus(value), new Decimal(0));
}

/**
 * Decimals are serialised as fixed-precision strings so no precision is lost
 * on the way to a JavaScript client.
 *
 * @param {Prisma.Decimal | null | undefined} value
 */
export function serializeMoney(value) {
  return value == null ? null : new Decimal(value).toFixed(MONEY_DP);
}

/**
 * The same, for `numeric(14,3)` quantities - fixed precision rather than
 * Decimal's default trimming, so "2" and "2.000" never both appear for the
 * same column.
 *
 * @param {Prisma.Decimal | null | undefined} value
 */
export function serializeQuantity(value) {
  return value == null ? null : new Decimal(value).toFixed(QUANTITY_DP);
}
