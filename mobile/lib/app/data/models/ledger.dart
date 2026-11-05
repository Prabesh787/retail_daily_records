import '../../core/domain/money.dart';
import '../../core/utils/date_utils.dart';
import '../enums/payment_status.dart';

/// Where a line on an account's ledger came from, which is also where tapping
/// it leads.
enum MovementSource { sale, customerPayment, supplierPayment, entry }

/// One cleared movement of money through an account. Derived from the records
/// that caused it, never stored.
class AccountMovement {
  const AccountMovement({
    required this.source,
    required this.recordId,
    required this.movedOn,
    required this.createdAt,
    required this.isIn,
    required this.amount,
    required this.title,
    this.isTransfer = false,
    this.balanceAfter = Money.zero,
  });

  factory AccountMovement.fromMap(Map<String, dynamic> map) => AccountMovement(
    source: MovementSource.values.byName(map['source'] as String),
    recordId: map['record_id'] as String,
    movedOn: (map['moved_on'] as int?) ?? 0,
    createdAt: (map['created_at'] as int?) ?? 0,
    isIn: (map['direction'] as int) > 0,
    amount: Money.fromColumn(map['amount']),
    title: (map['title'] as String?) ?? '',
    isTransfer: (map['is_transfer'] as int? ?? 0) == 1,
  );

  final MovementSource source;
  final String recordId;
  final int movedOn;
  final int createdAt;
  final bool isIn;
  final Money amount;
  final String title;
  final bool isTransfer;

  /// Filled in by the repository as it walks the ledger oldest-first.
  final Money balanceAfter;

  AccountMovement withBalance(Money balance) => AccountMovement(
    source: source,
    recordId: recordId,
    movedOn: movedOn,
    createdAt: createdAt,
    isIn: isIn,
    amount: amount,
    title: title,
    isTransfer: isTransfer,
    balanceAfter: balance,
  );
}

/// The four documents the History tab lists together.
enum ActivityKind {
  sale('Sale'),
  purchase('Purchase'),
  paymentIn('Payment In'),
  paymentOut('Payment Out');

  const ActivityKind(this.label);

  final String label;

  /// Green for money coming in, red for money going out. The one colour rule the
  /// whole app follows.
  bool get isMoneyIn => this == sale || this == paymentIn;

  static ActivityKind fromDb(String value) => ActivityKind.values.byName(value);
}

/// One row on the History tab.
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.id,
    required this.dateMs,
    required this.createdAt,
    required this.amount,
    this.paid = Money.zero,
    this.partyName,
    this.docNo,
    this.mode,
    this.status = PaymentStatus.cleared,
  });

  factory ActivityItem.fromMap(Map<String, dynamic> map) => ActivityItem(
    kind: ActivityKind.fromDb(map['kind'] as String),
    id: map['id'] as String,
    dateMs: (map['date_ms'] as int?) ?? 0,
    createdAt: (map['created_at'] as int?) ?? 0,
    amount: Money.fromColumn(map['amount']),
    paid: Money.fromColumn(map['paid']),
    partyName: map['party_name'] as String?,
    docNo: map['doc_no'] as String?,
    mode: map['mode'] as String?,
    status: PaymentStatus.fromValue(map['status'] as String?),
  );

  final ActivityKind kind;
  final String id;
  final int dateMs;
  final int createdAt;
  final Money amount;

  /// Sales and purchases only: what has been settled against the document.
  final Money paid;

  final String? partyName;
  final String? docNo;
  final String? mode;
  final PaymentStatus status;

  bool get isDocument =>
      kind == ActivityKind.sale || kind == ActivityKind.purchase;

  Money get due {
    final left = amount - paid;
    return left.isNegative ? Money.zero : left;
  }
}

/// Which side of a cheque the shop is on.
enum ChequeDirection { toCollect, toPay }

/// Where a cheque is recorded. The three tables stay as they are; the register
/// is a view over them.
enum ChequeSource { saleLine, customerPayment, supplierPayment }

/// A cheque in the register, whichever record it belongs to.
class ChequeItem {
  const ChequeItem({
    required this.source,
    required this.id,
    required this.parentId,
    required this.direction,
    required this.amount,
    required this.dueMs,
    required this.issuedMs,
    required this.status,
    this.partyName,
    this.chequeNo,
    this.accountId,
    this.accountName,
    this.clearedDate,
  });

  factory ChequeItem.fromMap(Map<String, dynamic> map) {
    final source = ChequeSource.values.byName(map['source'] as String);
    return ChequeItem(
      source: source,
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      direction: source == ChequeSource.supplierPayment
          ? ChequeDirection.toPay
          : ChequeDirection.toCollect,
      amount: Money.fromColumn(map['amount']),
      dueMs: (map['due_ms'] as int?) ?? 0,
      issuedMs: (map['issued_ms'] as int?) ?? 0,
      status: PaymentStatus.fromValue(map['status'] as String?),
      partyName: map['party_name'] as String?,
      chequeNo: map['cheque_no'] as String?,
      accountId: map['account_id'] as String?,
      accountName: map['account_name'] as String?,
      clearedDate: map['cleared_date'] as int?,
    );
  }

  final ChequeSource source;

  /// The payment or sale-line id.
  final String id;

  /// The record a tap opens: the sale for a sale line, otherwise [id].
  final String parentId;

  final ChequeDirection direction;
  final Money amount;
  final int dueMs;
  final int issuedMs;
  final PaymentStatus status;
  final String? partyName;
  final String? chequeNo;
  final String? accountId;
  final String? accountName;
  final int? clearedDate;

  bool get isPending => status == PaymentStatus.issued;

  /// Negative once the date on the cheque has passed.
  int get daysLeft => AppDateUtils.daysUntil(dueMs);

  /// Worth raising on the home screen: overdue, or due within the week.
  bool get needsAttention => isPending && daysLeft <= 7;
}
