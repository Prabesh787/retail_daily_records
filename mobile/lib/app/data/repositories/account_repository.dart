import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/account_type.dart';
import '../enums/sync_status.dart';
import '../models/account_entry.dart';
import '../models/ledger.dart';
import '../models/money_account.dart';
import 'base_repository.dart';

/// What the Accounts tab shows, read once.
class AccountsOverview {
  const AccountsOverview({required this.accounts, required this.unassigned});

  final List<MoneyAccount> accounts;

  /// Bank money with no bank named. See [AccountDao.unassignedTotal].
  final Money unassigned;

  Money get cash => Money.sum(
    accounts.where((a) => a.isCash).map((a) => a.balance),
  );

  Money get bank =>
      Money.sum(accounts.where((a) => !a.isCash).map((a) => a.balance)) +
      unassigned;

  Money get total => cash + bank;
}

class AccountRepository extends BaseRepository {
  @override
  String get entity => DbTables.account;

  /// Reads the accounts, setting up the cash box the first time it is needed.
  Future<List<MoneyAccount>> list({bool includeInactive = false}) async {
    await ensureCashAccount();
    return dbService.accounts.all(includeInactive: includeInactive);
  }

  Future<AccountsOverview> overview() async => AccountsOverview(
    accounts: await list(),
    unassigned: await dbService.accounts.unassignedTotal(),
  );

  Future<MoneyAccount?> byId(String id) => dbService.accounts.byId(id);

  /// One account's movements newest first, each with the balance it left behind.
  ///
  /// Walked oldest-first because a running balance only exists in that
  /// direction, then reversed for reading. Null [account] reads the unassigned
  /// rows, which have no opening balance.
  Future<List<AccountMovement>> ledger(MoneyAccount? account) async {
    final rows = await dbService.accounts.movements(account?.id);

    var balance = account?.openingBalance ?? Money.zero;
    final walked = <AccountMovement>[];
    for (final row in rows) {
      balance = row.isIn ? balance + row.amount : balance - row.amount;
      walked.add(row.withBalance(balance));
    }
    return walked.reversed.toList();
  }

  /// The cash box has a fixed id, and a real edit must always beat this seed:
  /// a phone setting up today must not overwrite an opening balance another
  /// phone entered last week. So it is stamped with the oldest possible version,
  /// and last-write-wins does the rest.
  Future<void> ensureCashAccount() async {
    final rows = await dbService.db.query(
      DbTables.account,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [MoneyAccount.cashId],
      limit: 1,
    );
    if (rows.isNotEmpty) return;

    const seedVersion = 1;
    final cash = MoneyAccount(
      id: MoneyAccount.cashId,
      createdAt: nowMs,
      updatedAt: seedVersion,
      name: 'Cash',
      accountType: AccountType.cash,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );

    await dbService.transaction((txn) async {
      await dbService.accounts.upsert(txn, cash);
      await enqueue(
        txn,
        entity: DbTables.account,
        entityId: cash.id,
        payload: cash.toJson(),
        updatedAt: seedVersion,
      );
    });
  }

  Future<MoneyAccount> save(MoneyAccount account) async {
    final name = account.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('An account needs a name.');
    }

    final timestamp = nowMs;
    final isNew = account.id.isEmpty;

    final stamped = isNew
        ? MoneyAccount(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            name: name,
            accountType: account.accountType,
            accountNo: account.accountNo,
            openingBalance: account.openingBalance,
            isActive: account.isActive,
            remarks: account.remarks,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : account.copyWith(
            name: name,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.accounts.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.account,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });
    return stamped;
  }

  /// A deposit, withdrawal, transfer, expense or correction.
  Future<AccountEntry> saveEntry({
    required int dateMs,
    required Money amount,
    String? fromAccountId,
    String? toAccountId,
    String? description,
  }) async {
    if (!amount.isPositive) {
      throw const ValidationException('The amount has to be more than zero.');
    }
    if (fromAccountId == null && toAccountId == null) {
      throw const ValidationException('Choose an account.');
    }
    if (fromAccountId == toAccountId) {
      throw const ValidationException(
        'Choose two different accounts for a transfer.',
      );
    }

    final timestamp = nowMs;
    final entry = AccountEntry(
      id: newId(),
      createdAt: timestamp,
      updatedAt: timestamp,
      entryDate: dateMs,
      entryDateBs: NepaliDate.msToBs(dateMs),
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      description: description,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );

    await write((txn) async {
      await dbService.accounts.upsertEntry(txn, entry);
      await enqueue(
        txn,
        entity: DbTables.accountEntry,
        entityId: entry.id,
        payload: entry.toJson(),
        updatedAt: timestamp,
      );
    });
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final existing = await dbService.accounts.entryById(id);
    if (existing == null) return;

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.accounts.softDeleteEntry(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.accountEntry,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}
