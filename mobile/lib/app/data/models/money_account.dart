import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../enums/account_type.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// The cash box, a bank account or a wallet.
///
/// The balance is never stored. It is the opening balance plus every cleared
/// movement naming the account, the same way a supplier's outstanding is derived
/// from bills and payments, so it cannot drift from the records under it.
class MoneyAccount extends SyncableModel {
  const MoneyAccount({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.accountType,
    this.accountNo,
    this.openingBalance = Money.zero,
    this.isActive = true,
    this.remarks,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.movementTotal,
  });

  /// The cash box has one fixed id, so two phones setting up offline end up with
  /// one cash account rather than two.
  static const String cashId = '00000000-0000-4000-8000-000000000001';

  final String name;
  final AccountType accountType;
  final String? accountNo;
  final Money openingBalance;
  final bool isActive;
  final String? remarks;

  /// Joined in by the balance query; null when the query did not ask for it.
  final Money? movementTotal;

  bool get isCash => id == cashId;

  Money get balance => openingBalance + (movementTotal ?? Money.zero);

  @override
  Map<String, dynamic> toMap() => {
    ...syncMap,
    'name': name,
    'account_type': accountType.value,
    'account_no': accountNo,
    'opening_balance': openingBalance.toColumn(),
    'is_active': isActive ? 1 : 0,
    'remarks': remarks,
  };

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'accountType': accountType.value,
    'accountNo': accountNo,
    'openingBalance': openingBalance.toWire(),
    'isActive': isActive,
    'remarks': remarks,
    ...syncJson,
  };

  factory MoneyAccount.fromMap(Map<String, dynamic> map) => MoneyAccount(
    id: SyncableModel.idOf(map),
    createdAt: SyncableModel.createdAtOf(map),
    updatedAt: SyncableModel.updatedAtOf(map),
    isDeleted: SyncableModel.isDeletedOf(map),
    syncStatus: SyncableModel.syncStatusOf(map),
    deviceId: SyncableModel.deviceIdOf(map),
    name: (map['name'] as String?) ?? '',
    accountType: AccountType.fromValue(map['account_type'] as String?),
    accountNo: map['account_no'] as String?,
    openingBalance: Money.fromColumn(map['opening_balance']),
    isActive: (map['is_active'] as int? ?? 1) == 1,
    remarks: map['remarks'] as String?,
    movementTotal: map.containsKey('movement_total')
        ? Money.fromColumn(map['movement_total'])
        : null,
  );

  MoneyAccount copyWith({
    String? name,
    AccountType? accountType,
    String? accountNo,
    Money? openingBalance,
    bool? isActive,
    String? remarks,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
  }) => MoneyAccount(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    name: name ?? this.name,
    accountType: accountType ?? this.accountType,
    accountNo: accountNo ?? this.accountNo,
    openingBalance: openingBalance ?? this.openingBalance,
    isActive: isActive ?? this.isActive,
    remarks: remarks ?? this.remarks,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    deviceId: deviceId ?? this.deviceId,
    movementTotal: movementTotal,
  );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.account} (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL,
      account_type    TEXT NOT NULL DEFAULT 'BANK',
      account_no      TEXT,
      opening_balance INTEGER NOT NULL DEFAULT 0,
      is_active       INTEGER NOT NULL DEFAULT 1,
      remarks         TEXT,
      ${SyncColumns.definition}
    )
  ''';
}
