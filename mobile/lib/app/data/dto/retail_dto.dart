/// Translation between the retail models and the backend's JSON.
///
/// This layer exists so that a change on the server's side of the wire changes
/// this file and nothing else — not the DAOs, not the repositories, not a
/// controller or a view.
///
/// **Casing.** Domain fields are camelCase, matching the serializers the
/// Express backend already has; the four sync metadata keys are snake_case,
/// because `SyncEngine` reads `updated_at` and `device_id` straight off a
/// pulled row. See `SyncableModel.syncJson`.
///
/// **Dates.** Document dates travel as AD `YYYY-MM-DD` with the BS string
/// beside them, read through [WireCodec.dateMs], which parses as UTC midnight.
/// Timestamps travel as epoch millis.
///
/// **Money.** Fixed-precision strings, never numbers.
library;

import '../enums/payment_status.dart';
import '../enums/sale_payment_mode.dart';
import '../enums/sale_type.dart';
import '../enums/supplier_payment_mode.dart';
import '../enums/sync_status.dart';
import '../models/customer.dart';
import '../models/fiscal_year.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sale_payment.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import 'wire_codec.dart';

/// Anything that arrived from the server is by definition already synced —
/// writing it back as pending would push it straight out again.
const SyncStatus _fromServer = SyncStatus.synced;

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class FiscalYearDto {
  FiscalYearDto._();

  static Map<String, dynamic> toWire(FiscalYear year) => year.toJson();

  static FiscalYear fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    return FiscalYear(
      id: WireCodec.string(json['id']),
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      name: WireCodec.string(json['name']),
      startDate: WireCodec.dateMs(json['startDate']) ?? 0,
      endDate: WireCodec.dateMs(json['endDate']) ?? 0,
      startDateBs: WireCodec.stringOrNull(json['startDateBs']),
      endDateBs: WireCodec.stringOrNull(json['endDateBs']),
      isActive: WireCodec.boolean(json['isActive']),
    );
  }
}

class SupplierDto {
  SupplierDto._();

  static Map<String, dynamic> toWire(Supplier supplier) => supplier.toJson();

  static Supplier fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    return Supplier(
      id: WireCodec.string(json['id']),
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      name: WireCodec.string(json['name']),
      contactPerson: WireCodec.stringOrNull(json['contactPerson']),
      phone: WireCodec.stringOrNull(json['phone']),
      email: WireCodec.stringOrNull(json['email']),
      address: WireCodec.stringOrNull(json['address']),
      pan: WireCodec.stringOrNull(json['pan']),
      openingBalance: WireCodec.money(json['openingBalance']),
      isActive: WireCodec.boolean(json['isActive'], fallback: true),
      remarks: WireCodec.stringOrNull(json['remarks']),
    );
  }
}

class CustomerDto {
  CustomerDto._();

  static Map<String, dynamic> toWire(Customer customer) => customer.toJson();

  static Customer fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    return Customer(
      id: WireCodec.string(json['id']),
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      name: WireCodec.string(json['name']),
      phone: WireCodec.stringOrNull(json['phone']),
      address: WireCodec.stringOrNull(json['address']),
      pan: WireCodec.stringOrNull(json['pan']),
      remarks: WireCodec.stringOrNull(json['remarks']),
    );
  }
}

class PurchaseDto {
  PurchaseDto._();

  static Map<String, dynamic> toWire(Purchase purchase) => purchase.toJson();

  static Purchase fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    return Purchase(
      id: WireCodec.string(json['id']),
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      fiscalYearId: WireCodec.string(json['fiscalYearId']),
      supplierId: WireCodec.string(json['supplierId']),
      billNo: WireCodec.string(json['billNo']),
      billDate: WireCodec.dateMs(json['billDate']) ?? 0,
      billDateBs: WireCodec.stringOrNull(json['billDateBs']),
      description: WireCodec.stringOrNull(json['description']),
      amount: WireCodec.money(json['amount']),
      remarks: WireCodec.stringOrNull(json['remarks']),
      createdById: WireCodec.stringOrNull(json['createdById']),
    );
  }
}

class SupplierPaymentDto {
  SupplierPaymentDto._();

  static Map<String, dynamic> toWire(SupplierPayment payment) =>
      payment.toJson();

  static SupplierPayment fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    return SupplierPayment(
      id: WireCodec.string(json['id']),
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      fiscalYearId: WireCodec.string(json['fiscalYearId']),
      supplierId: WireCodec.string(json['supplierId']),
      purchaseId: WireCodec.stringOrNull(json['purchaseId']),
      voucherNo: WireCodec.stringOrNull(json['voucherNo']),
      paymentDate: WireCodec.dateMs(json['paymentDate']) ?? 0,
      paymentDateBs: WireCodec.stringOrNull(json['paymentDateBs']),
      paymentMode: SupplierPaymentMode.fromValue(
        WireCodec.stringOrNull(json['paymentMode']),
      ),
      amount: WireCodec.money(json['amount']),
      chequeNo: WireCodec.stringOrNull(json['chequeNo']),
      chequeDate: WireCodec.dateMs(json['chequeDate']),
      chequeDateBs: WireCodec.stringOrNull(json['chequeDateBs']),
      referenceNo: WireCodec.stringOrNull(json['referenceNo']),
      clearedDate: WireCodec.dateMs(json['clearedDate']),
      status: PaymentStatus.fromValue(WireCodec.stringOrNull(json['status'])),
      description: WireCodec.stringOrNull(json['description']),
      remarks: WireCodec.stringOrNull(json['remarks']),
      createdById: WireCodec.stringOrNull(json['createdById']),
    );
  }
}

class SaleDto {
  SaleDto._();

  static Map<String, dynamic> toWire(Sale sale) => sale.toJson();

  /// The lines and payments ride inside the header's payload, so they are read
  /// back out here rather than pulled as entities of their own.
  static Sale fromWire(Map<String, dynamic> json) {
    final now = _nowMs();
    final id = WireCodec.string(json['id']);

    final items = <SaleItem>[];
    for (final (index, raw) in WireCodec.objects(json['items']).indexed) {
      items.add(SaleItemDto.fromWire(raw, saleId: id, fallbackOrder: index));
    }

    return Sale(
      id: id,
      createdAt: WireCodec.millis(json['created_at'], fallback: now),
      updatedAt: WireCodec.millis(json['updated_at'], fallback: now),
      isDeleted: WireCodec.boolean(json['is_deleted']),
      syncStatus: _fromServer,
      deviceId: WireCodec.stringOrNull(json['device_id']),
      fiscalYearId: WireCodec.string(json['fiscalYearId']),
      invoiceNo: WireCodec.stringOrNull(json['invoiceNo']),
      saleDate: WireCodec.dateMs(json['saleDate']) ?? 0,
      saleDateBs: WireCodec.stringOrNull(json['saleDateBs']),
      customerId: WireCodec.stringOrNull(json['customerId']),
      saleType: SaleType.fromValue(WireCodec.stringOrNull(json['saleType'])),
      description: WireCodec.stringOrNull(json['description']),
      subtotal: WireCodec.money(json['subtotal']),
      discount: WireCodec.money(json['discount']),
      totalAmount: WireCodec.money(json['totalAmount']),
      remarks: WireCodec.stringOrNull(json['remarks']),
      createdById: WireCodec.stringOrNull(json['createdById']),
      items: items,
      payments: WireCodec.objects(json['payments'])
          .map((raw) => SalePaymentDto.fromWire(raw, saleId: id))
          .toList(),
    );
  }
}

class SaleItemDto {
  SaleItemDto._();

  static Map<String, dynamic> toWire(SaleItem item) => item.toJson();

  /// [fallbackOrder] is the line's position in the array, used when a row
  /// arrives without a `sortOrder` — a sale recorded before the server had the
  /// column, say. Array order is the best available answer, and better than
  /// letting the lines come back shuffled.
  static SaleItem fromWire(
    Map<String, dynamic> json, {
    required String saleId,
    int fallbackOrder = 0,
  }) =>
      SaleItem(
        id: WireCodec.string(json['id']),
        saleId: WireCodec.stringOrNull(json['saleId']) ?? saleId,
        description: WireCodec.string(json['description']),
        quantity: WireCodec.quantity(json['quantity']),
        unit: WireCodec.stringOrNull(json['unit']) ?? 'PCS',
        unitPrice: WireCodec.money(json['unitPrice']),
        discount: WireCodec.money(json['discount']),
        sortOrder: json['sortOrder'] == null
            ? fallbackOrder
            : WireCodec.integer(json['sortOrder']),
      );
}

class SalePaymentDto {
  SalePaymentDto._();

  static Map<String, dynamic> toWire(SalePayment payment) => payment.toJson();

  static SalePayment fromWire(
    Map<String, dynamic> json, {
    required String saleId,
  }) =>
      SalePayment(
        id: WireCodec.string(json['id']),
        saleId: WireCodec.stringOrNull(json['saleId']) ?? saleId,
        paymentMode: SalePaymentMode.fromValue(
          WireCodec.stringOrNull(json['paymentMode']),
        ),
        amount: WireCodec.money(json['amount']),
        referenceNo: WireCodec.stringOrNull(json['referenceNo']),
        chequeNo: WireCodec.stringOrNull(json['chequeNo']),
        chequeDate: WireCodec.dateMs(json['chequeDate']),
        clearedDate: WireCodec.dateMs(json['clearedDate']),
        status: PaymentStatus.fromValue(WireCodec.stringOrNull(json['status'])),
        remarks: WireCodec.stringOrNull(json['remarks']),
      );
}
