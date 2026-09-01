import { env } from '../../config/index.js';
import { Decimal, serializeMoney } from '../../common/utils/money.js';
import {
  addDays,
  adToBs,
  isoDaysEndingOn,
  toDbDate,
  toIsoDate,
  todayInTimeZone,
} from '../../common/utils/nepali-date.js';
import { listSuppliersWithBalance } from '../suppliers/supplier-balance.js';
import { reportRepository } from './report.repository.js';
import {
  serializeFiscalYear,
  serializePayment,
  serializePurchase,
  serializeSale,
} from '../../common/serializers/index.js';

/**
 * Reports are read-only views assembled from the transaction tables. Nothing
 * here is stored: ask twice and you get the current answer twice, which is the
 * whole point of deriving supplier liability rather than keeping a running
 * total.
 *
 * "Today" is the calendar day in the shop's timezone, not the server's UTC
 * date - see APP_TIMEZONE in config/env.js.
 *
 * Every date in the payload is a pair: the AD value the database sorts on and
 * the BS value the shop reads.
 */

/** Default window when the caller does not name one: 30 days ending today. */
const DEFAULT_WINDOW_DAYS = 30;
const RECENT_ROWS = 4;
const UPCOMING_CHEQUES = 3;

/** A `YYYY-MM-DD` day expressed in both calendars. */
const day = (isoDate) => ({ date: isoDate, dateBs: adToBs(isoDate) });

export const reportService = {
  /**
   * Everything the home screen shows, in one round trip: today's takings, the
   * window totals, what is owed to suppliers, which cheques are about to be
   * presented, a sales trend and the latest records.
   *
   * @param {{ from?: Date, to?: Date, trendDays?: number, topSuppliers?: number }} query
   */
  async dashboard(query = {}) {
    const today = todayInTimeZone(env.APP_TIMEZONE);
    const trendDays = query.trendDays ?? 14;
    const topSuppliers = query.topSuppliers ?? RECENT_ROWS;

    // The window ends today unless asked otherwise, and starts 30 days back
    // from wherever it ends, so `?to=` alone still gives a full window.
    const to = toIsoDate(query.to) ?? today;
    const from = toIsoDate(query.from) ?? addDays(to, -(DEFAULT_WINDOW_DAYS - 1));

    const todayDate = toDbDate(today);
    const trendDayList = isoDaysEndingOn(today, trendDays);

    const [
      todaySales,
      windowSales,
      windowPurchases,
      windowPayments,
      salesPerDay,
      cheques,
      recentSales,
      recentPurchases,
      suppliers,
      fiscalYear,
    ] = await Promise.all([
      reportRepository.salesSummary(todayDate, todayDate),
      reportRepository.salesSummary(toDbDate(from), toDbDate(to)),
      reportRepository.purchasesSummary(toDbDate(from), toDbDate(to)),
      reportRepository.supplierPaymentsSummary(toDbDate(from), toDbDate(to)),
      reportRepository.salesPerDay(toDbDate(trendDayList[0]), todayDate),
      reportRepository.unclearedCheques(UPCOMING_CHEQUES),
      reportRepository.recentSales(RECENT_ROWS),
      reportRepository.recentPurchases(RECENT_ROWS),
      listSuppliersWithBalance({ onlyOutstanding: true }),
      reportRepository.activeFiscalYear(),
    ]);

    const payableTotal = suppliers.reduce(
      (total, supplier) => total.plus(supplier.balance.outstanding),
      new Decimal(0),
    );

    // Grouped rows keyed by day, so the gaps can be filled with zero below.
    const salesByDay = new Map(salesPerDay.map((row) => [toIsoDate(row.saleDate), row]));

    return {
      today: {
        ...day(today),
        salesTotal: serializeMoney(todaySales.total),
        salesCount: todaySales.count,
      },

      window: {
        from,
        fromBs: adToBs(from),
        to,
        toBs: adToBs(to),
        days: Math.max(1, Math.round((Date.parse(to) - Date.parse(from)) / 86_400_000) + 1),
        salesTotal: serializeMoney(windowSales.total),
        salesCount: windowSales.count,
        purchaseTotal: serializeMoney(windowPurchases.total),
        purchaseCount: windowPurchases.count,
        paymentTotal: serializeMoney(windowPayments.total),
        paymentCount: windowPayments.count,
      },

      payable: {
        total: serializeMoney(payableTotal),
        supplierCount: suppliers.length,
        top: suppliers.slice(0, topSuppliers).map(({ balance, ...supplier }) => ({
          supplier,
          balance,
        })),
      },

      cheques: {
        count: cheques.count,
        total: serializeMoney(cheques.total),
        next: cheques.next.map(serializePayment),
      },

      trend: trendDayList.map((date) => {
        const row = salesByDay.get(date);
        return {
          ...day(date),
          amount: serializeMoney(row?._sum.totalAmount ?? 0),
          count: row?._count._all ?? 0,
        };
      }),

      recentSales: recentSales.map(serializeSale),
      recentPurchases: recentPurchases.map(serializePurchase),
      fiscalYear: serializeFiscalYear(fiscalYear),
    };
  },

  /**
   * Every supplier with what is still owed to them, largest first - the
   * printable version of the dashboard's payable section.
   *
   * @param {{ onlyOutstanding?: boolean, isActive?: boolean }} query
   */
  async supplierOutstanding(query = {}) {
    const today = todayInTimeZone(env.APP_TIMEZONE);
    const suppliers = await listSuppliersWithBalance(query);

    const totals = suppliers.reduce(
      (acc, supplier) => ({
        outstanding: acc.outstanding.plus(supplier.balance.outstanding),
        uncleared: acc.uncleared.plus(supplier.balance.unclearedTotal),
      }),
      { outstanding: new Decimal(0), uncleared: new Decimal(0) },
    );

    return {
      asOf: day(today),
      totals: {
        outstanding: serializeMoney(totals.outstanding),
        uncleared: serializeMoney(totals.uncleared),
        supplierCount: suppliers.length,
        owingCount: suppliers.filter((row) => Number(row.balance.outstanding) > 0).length,
      },
      suppliers,
    };
  },
};
