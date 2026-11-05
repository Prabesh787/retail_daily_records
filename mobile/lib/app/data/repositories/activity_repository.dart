import 'package:get/get.dart';

import '../../core/constants/db_constants.dart';
import '../enums/payment_status.dart';
import '../models/ledger.dart';
import 'base_repository.dart';
import 'customer_payment_repository.dart';
import 'sale_repository.dart';
import 'supplier_payment_repository.dart';

/// The History tab and the cheque register: one read across several
/// documents, and one way of moving a cheque along whichever record it is on.
class ActivityRepository extends BaseRepository {
  /// Reads several tables and owns none. Nothing writes through this name.
  @override
  String get entity => DbTables.sale;

  Future<List<ActivityItem>> feed({
    ActivityKind? kind,
    String? search,
    int? fromMs,
    int? toMs,
    int? limit,
  }) => dbService.activity.feed(
    kind: kind,
    search: search,
    fromMs: fromMs,
    toMs: toMs,
    limit: limit,
  );

  Future<List<ChequeItem>> cheques({bool onlyPending = true}) =>
      dbService.activity.cheques(onlyPending: onlyPending);

  /// The money has moved. Each source records that on its own row, so the fact
  /// lands in the same place the record's other screens read it from.
  Future<void> clearCheque(
    ChequeItem cheque, {
    required String accountId,
    required int clearedOnMs,
  }) async {
    switch (cheque.source) {
      case ChequeSource.saleLine:
        await Get.find<SaleRepository>().updatePaymentLine(
          cheque.parentId,
          cheque.id,
          status: PaymentStatus.cleared,
          accountId: accountId,
          clearedOnMs: clearedOnMs,
        );
      case ChequeSource.customerPayment:
        await Get.find<CustomerPaymentRepository>().markCleared(
          cheque.id,
          accountId: accountId,
          clearedOnMs: clearedOnMs,
        );
      case ChequeSource.supplierPayment:
        await Get.find<SupplierPaymentRepository>().markCleared(
          cheque.id,
          accountId: accountId,
          clearedOnMs: clearedOnMs,
        );
    }
  }

  /// Bounced or voided. Whatever it was settling becomes owed again.
  Future<void> cancelCheque(ChequeItem cheque) async {
    switch (cheque.source) {
      case ChequeSource.saleLine:
        await Get.find<SaleRepository>().updatePaymentLine(
          cheque.parentId,
          cheque.id,
          status: PaymentStatus.cancelled,
        );
      case ChequeSource.customerPayment:
        await Get.find<CustomerPaymentRepository>().markCancelled(cheque.id);
      case ChequeSource.supplierPayment:
        await Get.find<SupplierPaymentRepository>().markCancelled(cheque.id);
    }
  }
}
