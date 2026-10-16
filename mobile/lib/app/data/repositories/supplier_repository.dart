import '../../core/constants/entities.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../enums/payment_status.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import 'base_repository.dart';

class SupplierRepository extends BaseRepository {
  @override
  String get entity => Entities.supplier;

  /// Ordered by what is owed, largest first — the list is a payables worklist,
  /// not an address book. The server sorts it that way and attaches each
  /// supplier's balance, so the order and the figures come from one answer.
  Future<List<Supplier>> list({
    String? search,
    bool onlyWithBalance = false,
    bool includeInactive = true,
    int? limit,
  }) async {
    final response = await api.suppliers(
      query: {
        'q': search,
        'limit': pageSize(limit),
        if (!includeInactive) 'isActive': 'true',
      },
    );

    final rows = response.rows.map(Supplier.fromJson);
    if (!onlyWithBalance) return rows.toList();

    // Narrowed here rather than by a query parameter, because the endpoint that
    // filters on the derived balance is the outstanding report — and a picker
    // asking "who do we owe" wants the same rows this list already carries.
    return rows.where((s) => !(s.balance?.isSettled ?? true)).toList();
  }

  Future<Supplier?> byId(String id) async {
    final statement = await this.statement(id);
    return statement?.supplier;
  }

  /// Everything the detail screen and the statement need for one supplier over
  /// one date window: the party, its all-time balance, the window's figures,
  /// and every movement inside the window.
  ///
  /// One call for both screens on purpose. They ask the same question and
  /// differ only in how they draw the answer — two calls would be two chances
  /// for the ledger and the report to disagree about the same supplier on the
  /// same dates, which is the one thing this product cannot do.
  ///
  /// [search] narrows the movements by bill, voucher or cheque number. It does
  /// **not** narrow the window figures: a filtered list under an unfiltered
  /// opening balance is a search result, while filtering both would produce a
  /// closing balance that is arithmetic on an arbitrary subset.
  Future<SupplierStatement?> statement(
    String id, {
    int? fromMs,
    int? toMs,
    String? search,
  }) async {
    if (id.isEmpty) return null;

    try {
      final response = await api.supplier(
        id,
        query: {...window(fromMs: fromMs, toMs: toMs), 'q': search},
      );
      return SupplierStatement.fromJson(response.object);
    } on ValidationException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Suppliers ranked by what is owed — the dashboard's "owed the most".
  Future<List<Supplier>> topOutstanding({int limit = 4}) async {
    final response = await api.supplierOutstanding(
      query: {'onlyOutstanding': 'true'},
    );

    final rows = (response.object['suppliers'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Supplier.fromJson)
        .toList();

    return rows.take(limit).toList();
  }

  /// Total payable across every supplier, and how many are actually owed
  /// anything — the two figures on the dashboard's payable tile.
  Future<({Money total, int supplierCount})> payable() async {
    final response = await api.supplierOutstanding(
      query: {'onlyOutstanding': 'true'},
    );
    final totals = response.object['totals'];

    if (totals is! Map<String, dynamic>) {
      return (total: Money.zero, supplierCount: 0);
    }
    return (
      total: Money.fromWire(totals['outstanding']),
      supplierCount: (totals['owingCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Supplier> save(Supplier supplier) async {
    final name = supplier.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A supplier needs a name.');
    }

    final isNew = supplier.id.isEmpty;
    final draft = supplier.copyWith(name: name);

    return write(() async {
      final response = isNew
          ? await api.createSupplier(draft.toRequestBody())
          : await api.updateSupplier(
              draft.id,
              draft.toRequestBody(includeIsActive: true),
            );
      return Supplier.fromJson(response.object);
    });
  }

  /// A supplier with documents against them refuses outright: their bills and
  /// payments would be orphaned and the derived balance would silently stop
  /// counting them. The server enforces that and names the count in its
  /// message, so the message is passed through as it is.
  Future<void> delete(String id) => write(() => api.deleteSupplier(id));

  /// The way to retire a supplier who has history.
  Future<Supplier?> setActive(String id, bool isActive) async {
    final existing = await byId(id);
    if (existing == null) return null;
    return save(existing.copyWith(isActive: isActive));
  }
}

/// One supplier's ledger over a date window.
///
/// Holds the movements once and exposes the two orderings the screens need,
/// rather than making each of them sort and interleave again:
///
///   * [movements] — newest first, for the detail screen's ledger tab, which is
///     a browsing list where the latest activity is what matters.
///   * [lines] — oldest first with a running balance, for the statement, which
///     is a document a supplier reconciles against from the top down.
class SupplierStatement {
  SupplierStatement({
    required this.supplier,
    required this.window,
    required this.purchases,
    required this.payments,
  });

  factory SupplierStatement.fromJson(Map<String, dynamic> json) =>
      SupplierStatement(
        supplier: Supplier.fromJson(json),
        window: SupplierWindow.fromJson(json['window']),
        purchases: (json['purchases'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Purchase.fromJson)
            .toList(),
        payments: (json['payments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SupplierPayment.fromJson)
            .toList(),
      );

  final Supplier supplier;
  final SupplierWindow window;

  /// Newest first, as the API returns them.
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;

  bool get isEmpty => purchases.isEmpty && payments.isEmpty;

  List<LedgerMovement>? _movements;

  /// Bills and payments as one column, newest first.
  List<LedgerMovement> get movements => _movements ??= [
        for (final purchase in purchases) LedgerMovement.bill(purchase),
        for (final payment in payments) LedgerMovement.payment(payment),
      ]..sort((a, b) => b.dateMs.compareTo(a.dateMs));

  List<LedgerMovement>? _lines;

  /// The same movements oldest first, each carrying the balance after it.
  ///
  /// The running figure starts at [SupplierWindow.openingAsOf] — the balance
  /// carried into the window — so the last line's balance is the closing
  /// balance in the header. If those two ever disagree, one of them is lying.
  ///
  /// A cancelled payment is listed but moves nothing: it appears in the column
  /// for the audit trail, with the running balance unchanged beside it.
  List<LedgerMovement> get lines {
    if (_lines != null) return _lines!;

    final ordered = movements.reversed.toList();
    var running = window.openingAsOf;

    _lines = [
      for (final movement in ordered)
        movement.at(running = running + movement.debit - movement.credit),
    ];
    return _lines!;
  }
}

/// One line in a supplier's ledger — a bill owed, or a payment made.
class LedgerMovement {
  const LedgerMovement({
    required this.id,
    required this.dateMs,
    required this.reference,
    this.purchase,
    this.payment,
    this.dateBs,
    this.detail,
    this.status,
    this.debit = Money.zero,
    this.credit = Money.zero,
    this.balance,
  });

  factory LedgerMovement.bill(Purchase purchase) => LedgerMovement(
        id: purchase.id,
        purchase: purchase,
        dateMs: purchase.billDate,
        dateBs: purchase.billDateBs,
        reference: 'Bill ${purchase.billNo}',
        detail: purchase.description,
        debit: purchase.amount,
      );

  factory LedgerMovement.payment(SupplierPayment payment) => LedgerMovement(
        id: payment.id,
        payment: payment,
        dateMs: payment.paymentDate,
        dateBs: payment.paymentDateBs,
        reference: payment.voucherNo == null
            ? payment.paymentMode.label
            : 'Voucher ${payment.voucherNo}',
        detail: [
          payment.paymentMode.label,
          if (payment.chequeNo != null) 'cheque ${payment.chequeNo}',
          if (payment.purchaseBillNo != null)
            'against bill ${payment.purchaseBillNo}',
        ].join(' · '),
        status: payment.status,
        // A cancelled payment settled nothing, so it credits nothing — the line
        // is kept for the audit trail, not for the arithmetic.
        credit: payment.recognisedAmount,
      );

  /// The record this line came from. Exactly one is set.
  ///
  /// Carried through so the detail screen can draw its ledger with the same
  /// `PurchaseRow` and `PaymentRow` every other list uses, instead of a third
  /// rendering of a bill that drifts away from the other two. The statement
  /// ignores these and reads the figures below.
  final Purchase? purchase;
  final SupplierPayment? payment;

  final String id;

  /// Bills raise what is owed; payments bring it down.
  bool get isBill => purchase != null;

  final int dateMs;
  final String? dateBs;
  final String reference;
  final String? detail;

  /// Payments only.
  final PaymentStatus? status;

  final Money debit;
  final Money credit;

  /// What was owed after this movement. Null in [SupplierStatement.movements],
  /// which is browsed rather than reconciled.
  final Money? balance;

  LedgerMovement at(Money running) => LedgerMovement(
        id: id,
        purchase: purchase,
        payment: payment,
        dateMs: dateMs,
        dateBs: dateBs,
        reference: reference,
        detail: detail,
        status: status,
        debit: debit,
        credit: credit,
        balance: running,
      );
}
