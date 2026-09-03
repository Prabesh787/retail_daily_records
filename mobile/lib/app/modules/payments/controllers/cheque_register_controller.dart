import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';

/// Cheques that have not cleared, in the order the money has to be there.
///
/// The register exists because an issued cheque is a commitment with a date on
/// it. Sorted by the date written on the cheque — not the day it was handed
/// over — it answers the only question worth asking of it: what has to be in
/// the account, and by when.
class ChequeRegisterController extends LoaderController<List<SupplierPayment>> {
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();

  /// Cleared cheques are history; the register is a forward-looking list. The
  /// toggle is there because reconciling last month means looking back.
  final RxBool onlyPending = true.obs;

  @override
  List<String> get watches => const [DbTables.supplierPayment];

  List<SupplierPayment> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  Future<List<SupplierPayment>> fetch() =>
      _payments.chequeRegister(onlyPending: onlyPending.value);

  /// The date the money is actually needed. Falls back to the payment date for
  /// a cheque recorded without one, so a row can never sort into nowhere.
  int _dueMs(SupplierPayment payment) =>
      payment.chequeDate ?? payment.paymentDate;

  /// Overdue, due within the week, and everything later.
  ///
  /// Those three because they are three different actions: chase it, make sure
  /// the money is there, and nothing yet.
  ({
    List<SupplierPayment> overdue,
    List<SupplierPayment> week,
    List<SupplierPayment> later,
  }) get buckets {
    final overdue = <SupplierPayment>[];
    final week = <SupplierPayment>[];
    final later = <SupplierPayment>[];

    for (final payment in rows) {
      final days = AppDateUtils.daysUntil(_dueMs(payment));
      if (days < 0) {
        overdue.add(payment);
      } else if (days <= 7) {
        week.add(payment);
      } else {
        later.add(payment);
      }
    }

    return (overdue: overdue, week: week, later: later);
  }

  Money get total => Money.sum(rows.map((p) => p.amount));

  Money get dueThisWeek {
    final split = buckets;
    // Overdue money is still owed and still has to be found, so it counts
    // toward what the week needs rather than dropping out of the figure.
    return Money.sum(
      [...split.overdue, ...split.week].map((p) => p.amount),
    );
  }

  void setOnlyPending(bool value) {
    onlyPending.value = value;
    load(silent: true);
  }

  void openPayment(SupplierPayment payment) => Get.toNamed<void>(
    Routes.paymentDetail,
    arguments: {RouteArgs.paymentId: payment.id},
  );
}
