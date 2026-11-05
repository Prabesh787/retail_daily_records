import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// Money moved with no party attached: a deposit, a withdrawal, a transfer, an
/// expense or a correction.
///
/// One row whichever way it goes. Money in names only [toAccountId], money out
/// names only [fromAccountId], and a transfer names both, so a transfer can
/// never be half recorded.
class AccountEntry extends SyncableModel {
  const AccountEntry({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.entryDate,
    required this.amount,
    this.entryDateBs,
    this.fromAccountId,
    this.toAccountId,
    this.description,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
  });

  final int entryDate;
  final String? entryDateBs;
  final String? fromAccountId;
  final String? toAccountId;
  final Money amount;
  final String? description;

  @override
  Map<String, dynamic> toMap() => {
    ...syncMap,
    'entry_date': entryDate,
    'entry_date_bs': entryDateBs,
    'from_account_id': fromAccountId,
    'to_account_id': toAccountId,
    'amount': amount.toColumn(),
    'description': description,
  };

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'entryDate': NepaliDate.toIsoDate(NepaliDate.fromMs(entryDate)),
    'entryDateBs': entryDateBs,
    'fromAccountId': fromAccountId,
    'toAccountId': toAccountId,
    'amount': amount.toWire(),
    'description': description,
    ...syncJson,
  };

  factory AccountEntry.fromMap(Map<String, dynamic> map) => AccountEntry(
    id: SyncableModel.idOf(map),
    createdAt: SyncableModel.createdAtOf(map),
    updatedAt: SyncableModel.updatedAtOf(map),
    isDeleted: SyncableModel.isDeletedOf(map),
    syncStatus: SyncableModel.syncStatusOf(map),
    deviceId: SyncableModel.deviceIdOf(map),
    entryDate: SyncableModel.toInt(map['entry_date']),
    entryDateBs: map['entry_date_bs'] as String?,
    fromAccountId: map['from_account_id'] as String?,
    toAccountId: map['to_account_id'] as String?,
    amount: Money.fromColumn(map['amount']),
    description: map['description'] as String?,
  );

  AccountEntry copyWith({
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
  }) => AccountEntry(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entryDate: entryDate,
    entryDateBs: entryDateBs,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amount: amount,
    description: description,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    deviceId: deviceId ?? this.deviceId,
  );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.accountEntry} (
      id              TEXT PRIMARY KEY,
      entry_date      INTEGER NOT NULL,
      entry_date_bs   TEXT,
      from_account_id TEXT,
      to_account_id   TEXT,
      amount          INTEGER NOT NULL DEFAULT 0,
      description     TEXT,
      ${SyncColumns.definition}
    )
  ''';
}
