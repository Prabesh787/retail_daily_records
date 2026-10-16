import '../../core/constants/entities.dart';
import '../../core/domain/money.dart';
import '../../core/domain/trend_point.dart';
import '../../core/utils/nepali_date.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import 'base_repository.dart';

/// The dashboard's single read.
///
/// One call, because the server already assembles this: today's takings, the
/// trend, what is owed, the cheques coming due and the latest records all come
/// out of `GET /reports/dashboard` together. Seven separate requests would give
/// the screen seven chances to be half-drawn, and a dashboard that fills in
/// piecemeal reads as broken on exactly the slow phone this app is for.
///
/// Every figure here has a screen behind it that shows the rows it came from,
/// and both read the same derivation on the server — so tapping through can
/// never land on a different number than the card that sent you.
class DashboardRepository extends BaseRepository {
  @override
  String get entity => Entities.sale;

  Future<DashboardData> load({int trendDays = 14}) async {
    final response = await api.dashboard(query: {'trendDays': trendDays});
    return DashboardData.fromJson(response.object);
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

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) =>
        json[key] is Map<String, dynamic>
            ? json[key] as Map<String, dynamic>
            : const {};

    List<Map<String, dynamic>> list(Object? value) => (value as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final today = section('today');
    final payable = section('payable');
    final cheques = section('cheques');
    final next = list(cheques['next']);

    return DashboardData(
      todaySales: Money.fromWire(today['salesTotal']),
      todayReceived: Money.fromWire(today['receivedTotal']),
      todayCount: (today['salesCount'] as num?)?.toInt() ?? 0,
      trend: list(json['trend']).map(_trendPoint).toList(),
      payableTotal: Money.fromWire(payable['total']),
      payableSupplierCount: (payable['supplierCount'] as num?)?.toInt() ?? 0,
      unclearedTotal: Money.fromWire(cheques['total']),
      unclearedCount: (cheques['count'] as num?)?.toInt() ?? 0,
      nextCheque: next.isEmpty ? null : SupplierPayment.fromJson(next.first),
      topOwed: list(payable['top']).map(_owedSupplier).toList(),
      latestSales: list(json['recentSales']).map(Sale.fromJson).toList(),
      latestBills: list(json['recentPurchases']).map(Purchase.fromJson).toList(),
    );
  }

  /// One point per day across the window, zeros included.
  ///
  /// The report fills the quiet days in rather than omitting them, which is
  /// what stops the line skipping the gaps and making a bad week look steady —
  /// the gaps are the information.
  static TrendPoint _trendPoint(Map<String, dynamic> json) => TrendPoint(
        dateMs:
            NepaliDate.parseIsoDate(json['date']?.toString() ?? '')
                    ?.millisecondsSinceEpoch ??
                0,
        amount: Money.fromWire(json['amount']),
      );

  /// The payable section nests the balance beside the supplier rather than
  /// inside it, so the two are folded back together into the one shape every
  /// other supplier row in the app already has.
  static Supplier _owedSupplier(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    if (supplier is! Map<String, dynamic>) return Supplier.fromJson(json);
    return Supplier.fromJson({...supplier, 'balance': json['balance']});
  }

  /// Sold today, credit included. [todayReceived] is what was actually taken —
  /// the same distinction the day book makes, kept here so the dashboard cannot
  /// quietly claim credit sales as cash.
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
