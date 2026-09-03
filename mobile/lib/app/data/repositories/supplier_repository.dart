import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../enums/sync_status.dart';
import '../enums/payment_status.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../providers/local/supplier_dao.dart';
import 'base_repository.dart';

class SupplierRepository extends BaseRepository {
  @override
  String get entity => DbTables.supplier;

  /// Ordered by what is owed, largest first — the list is a payables worklist,
  /// not an address book.
  Future<List<Supplier>> list({
    String? search,
    bool onlyWithBalance = false,
    bool includeInactive = true,
  }) =>
      dbService.suppliers.all(
        search: search,
        onlyWithBalance: onlyWithBalance,
        includeInactive: includeInactive,
      );

  Future<Supplier?> byId(String id) => dbService.suppliers.byId(id);

  /// Everything the detail screen and the statement need for one supplier over
  /// one date window: the party, its all-time balance, the window's figures,
  /// and every movement inside the window with a running balance.
  ///
  /// One method for both screens on purpose. They ask the same question and
  /// differ only in how they draw the answer — two implementations would be two
  /// chances for the ledger and the report to disagree about the same supplier
  /// on the same dates, which is the one thing this product cannot do.
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
    final supplier = await dbService.suppliers.byId(id);
    if (supplier == null) return null;

    final window = await dbService.suppliers.window(
      id,
      fromMs: fromMs,
      toMs: toMs,
    );

    final purchases = await dbService.purchases.all(
      supplierId: id,
      fromMs: fromMs,
      toMs: toMs,
      search: search,
    );
    final payments = await dbService.supplierPayments.all(
      supplierId: id,
      fromMs: fromMs,
      toMs: toMs,
      search: search,
    );

    return SupplierStatement(
      supplier: supplier,
      window: window,
      purchases: purchases,
      payments: payments,
    );
  }

  Future<List<Supplier>> topOutstanding({int limit = 4}) =>
      dbService.suppliers.topOutstanding(limit: limit);

  Future<({Money total, int supplierCount})> payable() =>
      dbService.suppliers.payable();

  Future<int> count() => dbService.suppliers.count();

  Future<bool> hasTransactions(String id) =>
      dbService.suppliers.hasTransactions(id);

  Future<Supplier> save(Supplier supplier) async {
    final name = supplier.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A supplier needs a name.');
    }

    final isNew = supplier.id.isEmpty;

    // Two suppliers with the same name is not illegal, but it is almost always
    // a duplicate being entered twice — and a duplicate splits one balance in
    // half, which is the failure this whole app exists to prevent.
    if (await dbService.suppliers
        .nameExists(name, exceptId: isNew ? null : supplier.id)) {
      throw ValidationException('There is already a supplier called $name.');
    }

    final timestamp = nowMs;
    final stamped = isNew
        ? Supplier(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            name: name,
            contactPerson: supplier.contactPerson,
            phone: supplier.phone,
            email: supplier.email,
            address: supplier.address,
            pan: supplier.pan,
            openingBalance: supplier.openingBalance,
            isActive: supplier.isActive,
            remarks: supplier.remarks,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : supplier.copyWith(
            name: name,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.suppliers.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.supplier,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });

    return stamped;
  }

  /// Soft delete only — a hard delete would be invisible to the other clients,
  /// which would resurrect the supplier on their next push.
  ///
  /// A supplier with documents against them refuses outright: their bills and
  /// payments would be orphaned and the derived balance would silently stop
  /// counting them. Deactivate instead.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    if (await dbService.suppliers.hasTransactions(id)) {
      throw ValidationException(
        '${existing.name} has bills or payments recorded. Mark them inactive '
        'instead of deleting them.',
      );
    }

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.suppliers.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.supplier,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }

  /// The way to retire a supplier who has history.
  Future<Supplier?> setActive(String id, bool isActive) async {
    final existing = await byId(id);
    if (existing == null) return null;
    return save(existing.copyWith(isActive: isActive));
  }
}

/// One supplier's ledger over a date window.
///
/// Holds the raw movements once and exposes the two orderings the screens
/// need, rather than making each of them sort and interleave again:
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

  final Supplier supplier;
  final SupplierWindow window;

  /// Newest first, as the DAOs return them.
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
    // A cancelled payment settled nothing, so it credits nothing — the line is
    // kept for the audit trail, not for the arithmetic.
    credit: payment.recognisedAmount,
  );

  /// The record this line came from. Exactly one is set.
  ///
  /// Carried through so the detail screen can draw its ledger with the same
  /// `PurchaseRow` and `PaymentRow` every other list uses, instead of a
  /// third rendering of a bill that drifts away from the other two. The
  /// statement ignores these and reads the figures below.
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
