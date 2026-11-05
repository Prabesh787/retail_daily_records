import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// Someone a sale was invoiced to.
///
/// Optional by design: a walk-in sale carries no customer at all, and most do
/// not. A customer record exists because someone asked for a proper invoice,
/// not because the shop keeps a directory.
class Customer extends SyncableModel {
  const Customer({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    this.phone,
    this.address,
    this.pan,
    this.remarks,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.saleCount,
    this.saleTotal,
    this.receivable,
  });

  final String name;
  final String? phone;
  final String? address;
  final String? pan;
  final String? remarks;

  /// Joined in by the list query, as the web's `/customers` endpoint does.
  ///
  /// Null means the query did not ask for them, which is different from zero: a
  /// screen that did not run the aggregate should show nothing rather than
  /// claim the customer has never bought anything.
  final int? saleCount;
  final Money? saleTotal;

  /// What they still owe: sold, less what was settled at the sale, less every
  /// Payment In. Derived by the same query, and null on the same terms.
  final Money? receivable;

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'name': name,
        'phone': phone,
        'address': address,
        'pan': pan,
        'remarks': remarks,
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'pan': pan,
        'remarks': remarks,
        ...syncJson,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        name: (map['name'] as String?) ?? '',
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        pan: map['pan'] as String?,
        remarks: map['remarks'] as String?,
        saleCount: map.containsKey('sale_count')
            ? SyncableModel.toInt(map['sale_count'])
            : null,
        saleTotal: map.containsKey('sale_total')
            ? Money.fromColumn(map['sale_total'])
            : null,
        receivable: map.containsKey('receivable')
            ? Money.fromColumn(map['receivable'])
            : null,
      );

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? pan,
    String? remarks,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    int? saleCount,
    Money? saleTotal,
    Money? receivable,
  }) =>
      Customer(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        pan: pan ?? this.pan,
        remarks: remarks ?? this.remarks,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
        saleCount: saleCount ?? this.saleCount,
        saleTotal: saleTotal ?? this.saleTotal,
        receivable: receivable ?? this.receivable,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.customer} (
      id      TEXT PRIMARY KEY,
      name    TEXT NOT NULL,
      phone   TEXT,
      address TEXT,
      pan     TEXT,
      remarks TEXT,
      ${SyncColumns.definition}
    )
  ''';
}
