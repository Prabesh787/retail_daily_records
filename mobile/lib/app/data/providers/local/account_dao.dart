import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/domain/money.dart';
import '../../enums/payment_status.dart';
import '../../enums/sale_payment_mode.dart';
import '../../models/account_entry.dart';
import '../../models/ledger.dart';
import '../../models/money_account.dart';

class AccountDao {
  const AccountDao(this._db);

  final Database _db;

  static final String _cleared = PaymentStatus.cleared.value;
  static final String _cash = SalePaymentMode.cash.value;
  static final String _credit = SalePaymentMode.credit.value;

  /// Every cleared movement of money, whichever record caused it.
  ///
  /// A cash row with no account predates accounts and belongs to the cash box. A
  /// bank row with no account also predates them, and stays null so it can be
  /// shown as unassigned rather than quietly counted against some bank.
  ///
  /// An uncleared cheque is absent on purpose: the money has not moved.
  static String get movementsSql => '''
    SELECT 'sale' AS source, s.id AS record_id,
      CASE WHEN sp.payment_mode = '$_cash'
        THEN COALESCE(sp.account_id, '${MoneyAccount.cashId}')
        ELSE sp.account_id END AS account_id,
      1 AS direction, sp.amount AS amount,
      COALESCE(sp.cleared_date, s.sale_date) AS moved_on, s.created_at AS created_at,
      COALESCE(c.name, 'Walk-in sale') AS title, 0 AS is_transfer
    FROM ${DbTables.salePayment} sp
    JOIN ${DbTables.sale} s ON s.id = sp.sale_id AND s.is_deleted = 0
    LEFT JOIN ${DbTables.customer} c ON c.id = s.customer_id
    WHERE sp.payment_mode <> '$_credit' AND sp.status = '$_cleared'

    UNION ALL
    SELECT 'customerPayment', cp.id,
      CASE WHEN cp.payment_mode = '$_cash'
        THEN COALESCE(cp.account_id, '${MoneyAccount.cashId}')
        ELSE cp.account_id END,
      1, cp.amount, COALESCE(cp.cleared_date, cp.payment_date), cp.created_at,
      COALESCE(c.name, 'Customer payment'), 0
    FROM ${DbTables.customerPayment} cp
    LEFT JOIN ${DbTables.customer} c ON c.id = cp.customer_id
    WHERE cp.is_deleted = 0 AND cp.status = '$_cleared'

    UNION ALL
    SELECT 'supplierPayment', sup.id,
      CASE WHEN sup.payment_mode = '$_cash'
        THEN COALESCE(sup.account_id, '${MoneyAccount.cashId}')
        ELSE sup.account_id END,
      -1, sup.amount, COALESCE(sup.cleared_date, sup.payment_date), sup.created_at,
      COALESCE(s.name, 'Supplier payment'), 0
    FROM ${DbTables.supplierPayment} sup
    LEFT JOIN ${DbTables.supplier} s ON s.id = sup.supplier_id
    WHERE sup.is_deleted = 0 AND sup.status = '$_cleared'

    UNION ALL
    SELECT 'entry', e.id, e.to_account_id, 1, e.amount, e.entry_date, e.created_at,
      COALESCE(e.description, 'Money in'),
      CASE WHEN e.from_account_id IS NOT NULL THEN 1 ELSE 0 END
    FROM ${DbTables.accountEntry} e
    WHERE e.is_deleted = 0 AND e.to_account_id IS NOT NULL

    UNION ALL
    SELECT 'entry', e.id, e.from_account_id, -1, e.amount, e.entry_date, e.created_at,
      COALESCE(e.description, 'Money out'),
      CASE WHEN e.to_account_id IS NOT NULL THEN 1 ELSE 0 END
    FROM ${DbTables.accountEntry} e
    WHERE e.is_deleted = 0 AND e.from_account_id IS NOT NULL
  ''';

  /// Accounts with their movements summed in, cash first, then by name.
  Future<List<MoneyAccount>> all({bool includeInactive = false}) async {
    final rows = await _db.rawQuery('''
      SELECT a.*, COALESCE(m.total, 0) AS movement_total
      FROM ${DbTables.account} a
      LEFT JOIN (
        SELECT account_id, SUM(direction * amount) AS total
        FROM ($movementsSql)
        WHERE account_id IS NOT NULL
        GROUP BY account_id
      ) m ON m.account_id = a.id
      WHERE a.is_deleted = 0 ${includeInactive ? '' : 'AND a.is_active = 1'}
      ORDER BY CASE WHEN a.id = ? THEN 0 ELSE 1 END, a.name COLLATE NOCASE ASC
    ''', [MoneyAccount.cashId]);
    return rows.map(MoneyAccount.fromMap).toList();
  }

  Future<MoneyAccount?> byId(String id) async {
    final rows = await _db.rawQuery('''
      SELECT a.*, COALESCE((
        SELECT SUM(direction * amount) FROM ($movementsSql) WHERE account_id = a.id
      ), 0) AS movement_total
      FROM ${DbTables.account} a
      WHERE a.id = ? AND a.is_deleted = 0
      LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : MoneyAccount.fromMap(rows.first);
  }

  /// Bank money recorded before accounts existed, or never given a bank. Kept
  /// visible so the total still adds up.
  Future<Money> unassignedTotal() async {
    final row = (await _db.rawQuery('''
      SELECT COALESCE(SUM(direction * amount), 0) AS total
      FROM ($movementsSql) WHERE account_id IS NULL
    ''')).first;
    return Money.fromColumn(row['total']);
  }

  /// One account's movements, oldest first. Null [accountId] reads the
  /// unassigned ones.
  Future<List<AccountMovement>> movements(String? accountId) async {
    final rows = await _db.rawQuery('''
      SELECT * FROM ($movementsSql)
      WHERE ${accountId == null ? 'account_id IS NULL' : 'account_id = ?'}
      ORDER BY moved_on ASC, created_at ASC
    ''', [?accountId]);
    return rows.map(AccountMovement.fromMap).toList();
  }

  /// Money through every account in a window. Transfers are left out: moving
  /// cash to the bank is neither income nor spending.
  Future<({Money moneyIn, Money moneyOut})> flowBetween(
    int fromMs,
    int toMs,
  ) async {
    final row = (await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN direction > 0 THEN amount ELSE 0 END), 0) AS money_in,
        COALESCE(SUM(CASE WHEN direction < 0 THEN amount ELSE 0 END), 0) AS money_out
      FROM ($movementsSql)
      WHERE is_transfer = 0 AND moved_on >= ? AND moved_on <= ?
    ''', [fromMs, toMs])).first;

    return (
      moneyIn: Money.fromColumn(row['money_in']),
      moneyOut: Money.fromColumn(row['money_out']),
    );
  }

  Future<AccountEntry?> entryById(String id) async {
    final rows = await _db.query(
      DbTables.accountEntry,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : AccountEntry.fromMap(rows.first);
  }

  Future<void> upsert(DatabaseExecutor txn, MoneyAccount account) async {
    await txn.insert(
      DbTables.account,
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertEntry(DatabaseExecutor txn, AccountEntry entry) async {
    await txn.insert(
      DbTables.accountEntry,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteEntry(
    DatabaseExecutor txn,
    String id,
    int updatedAt,
  ) async {
    await txn.update(
      DbTables.accountEntry,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
