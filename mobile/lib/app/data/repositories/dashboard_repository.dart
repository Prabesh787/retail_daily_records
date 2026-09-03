import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/date_utils.dart';
import '../../core/domain/trend_point.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import 'base_repository.dart';

/// The dashboard's single read.
///
/// Composes queries the other screens already own rather than adding new ones —
/// which is the whole reason this screen was built last. Every figure here has
/// a screen behind it that shows the rows it came from, and because both read
/// the same repository method, tapping through can never land on a different
/// number than the card that sent you.
class DashboardRepository extends BaseRepository {
  @override
  String get entity => DbTables.sale;

  /// Everything on the dashboard, in one call.
  ///
  /// Deliberately one method and one await point. Seven separate loads would
  /// give the screen seven chances to be half-drawn, and a dashboard that fills
  /// in piecemeal reads as broken on exactly the slow phone this app is for.
  Future<DashboardData> load({int trendDays = 14}) async {
    final todayStart = AppDateUtils.startOfTodayMs();
    final todayEnd = AppDateUtils.endOfTodayMs();

    // The window is inclusive of today, so 14 days means 13 back plus today —
    // an off-by-one here would silently drop today from its own trend.
    final trendFrom = AppDateUtils.daysAgoMs(trendDays - 1);

    final today = await dbService.sales.dayBook(todayStart);
    final dailyTotals = await dbService.sales.dailyTotals(trendFrom, todayEnd);
    final payable = await dbService.suppliers.payable();
    final topOwed = await dbService.suppliers.topOutstanding(limit: 4);
    final uncleared = await dbService.supplierPayments.uncleared();
    final dueCheques = await dbService.supplierPayments.chequeRegister(
      onlyPending: true,
      limit: 1,
    );
    final latestSales = await dbService.sales.all(limit: 3);
    final latestBills = await dbService.purchases.all(limit: 3);

    return DashboardData(
      todaySales: today.total,
      todayCount: today.count,
      todayReceived: Money.sum(today.sales.map((s) => s.settledTotal)),
      trend: _trend(dailyTotals, trendFrom, trendDays),
      payableTotal: payable.total,
      payableSupplierCount: payable.supplierCount,
      unclearedTotal: uncleared.total,
      unclearedCount: uncleared.count,
      nextCheque: dueCheques.isEmpty ? null : dueCheques.first,
      topOwed: topOwed,
      latestSales: latestSales,
      latestBills: latestBills,
    );
  }

  /// One point per day across the window, zeros included.
  ///
  /// The DAO returns only days that had sales. Plotting those alone would draw
  /// a line that skips the quiet days entirely and makes a bad week look like a
  /// steady one — the gaps are the information.
  List<TrendPoint> _trend(Map<int, Money> totals, int fromMs, int days) {
    final start = AppDateUtils.startOfDay(AppDateUtils.fromMs(fromMs));

    return [
      for (var i = 0; i < days; i++)
        () {
          final day = AppDateUtils.startOfDay(start.add(Duration(days: i)));
          final ms = day.millisecondsSinceEpoch;
          return TrendPoint(dateMs: ms, amount: totals[ms] ?? Money.zero);
        }(),
    ];
  }
}

/// What the dashboard shows, read once.
class DashboardData {
  const DashboardData({
    required this.todaySales,
    required this.todayCount,
    required this.todayReceived,
    required this.trend,
    required this.payableTotal,
    required this.payableSupplierCount,
    required this.unclearedTotal,
    required this.unclearedCount,
    required this.topOwed,
    required this.latestSales,
    required this.latestBills,
    this.nextCheque,
  });

  /// Sold today, credit included. [todayReceived] is what was actually taken —
  /// the same distinction the day book makes, kept here so the dashboard
  /// cannot quietly claim credit sales as cash.
  final Money todaySales;
  final Money todayReceived;
  final int todayCount;

  final List<TrendPoint> trend;

  final Money payableTotal;
  final int payableSupplierCount;

  final Money unclearedTotal;
  final int unclearedCount;

  /// The cheque whose date comes soonest, or none.
  final SupplierPayment? nextCheque;

  final List<Supplier> topOwed;
  final List<Sale> latestSales;
  final List<Purchase> latestBills;

  Money get todayOnCredit => todaySales - todayReceived;

  /// A shop that has recorded nothing at all. Worth distinguishing from a quiet
  /// day, because the two want different things said to them.
  bool get isFresh =>
      todayCount == 0 &&
      latestSales.isEmpty &&
      latestBills.isEmpty &&
      topOwed.isEmpty;
}
