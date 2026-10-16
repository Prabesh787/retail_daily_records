import '../../core/constants/entities.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../models/supplier_payment.dart';
import 'base_repository.dart';

class SupplierPaymentRepository extends BaseRepository {
  @override
  String get entity => Entities.supplierPayment;

  Future<List<SupplierPayment>> list({
    String? supplierId,
    String? purchaseId,
    String? fiscalYearId,
    PaymentStatus? status,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) async {
    final response = await api.payments(
      query: {
        ...window(fromMs: fromMs, toMs: toMs),
        'supplierId': supplierId,
        'purchaseId': purchaseId,
        'fiscalYearId': fiscalYearId,
        'status': status?.value,
        'q': search,
        'limit': pageSize(limit),
      },
    );
    return response.rows.map(SupplierPayment.fromJson).toList();
  }

  Future<SupplierPayment?> byId(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await api.payment(id);
      return SupplierPayment.fromJson(response.object);
    } on ValidationException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Cheques in the order the money has to be available — by the date written
  /// on them, not the day they were handed over.
  ///
  /// [onlyPending] narrows to the cheques the bank has not taken yet, which is
  /// what makes this a forward-looking list rather than a history.
  Future<List<SupplierPayment>> chequeRegister({
    bool onlyPending = true,
    int? fromMs,
    int? toMs,
    int? limit,
  }) async {
    final response = await api.chequeRegister(
      query: {
        ...window(fromMs: fromMs, toMs: toMs),
        if (onlyPending) 'status': PaymentStatus.issued.value,
        'limit': pageSize(limit),
      },
    );
    return response.rows.map(SupplierPayment.fromJson).toList();
  }

  /// Cheques handed over that the bank has not debited yet — the dashboard's
  /// "waiting to clear" tile.
  Future<({Money total, int count})> uncleared() async {
    final rows = await chequeRegister();
    return (
      total: Money.sum(rows.map((payment) => payment.amount)),
      count: rows.length,
    );
  }

  /// Records a payment to a supplier.
  ///
  /// A cheque is filed as ISSUED rather than CLEARED, because handing one over
  /// is not the same as the bank debiting it — that difference is the whole
  /// reason this app keeps a cheque register. The server applies that default,
  /// so it is not restated here.
  Future<SupplierPayment> save(SupplierPayment payment) async {
    if (payment.supplierId.isEmpty) {
      throw const ValidationException('A payment needs a supplier.');
    }
    if (!payment.amount.isPositive) {
      throw const ValidationException('A payment has to be more than zero.');
    }
    if (payment.paymentMode.isCheque &&
        (payment.chequeNo == null || payment.chequeNo!.trim().isEmpty)) {
      throw const ValidationException('A cheque payment needs its number.');
    }

    return write(() async {
      final response = await api.createPayment(payment.toRequestBody());
      return SupplierPayment.fromJson(response.object);
    });
  }

  /// The money has actually left the bank.
  ///
  /// [clearedOnMs] defaults to the cheque's own date rather than today: a
  /// cheque marked cleared a week late still cleared on the day the bank
  /// debited it, and the reports read that date.
  Future<SupplierPayment?> markCleared(String id, {int? clearedOnMs}) async {
    final existing = await byId(id);
    if (existing == null) return null;

    if (existing.status == PaymentStatus.cancelled) {
      throw const ValidationException(
        'A cancelled payment cannot be cleared. Record a new one.',
      );
    }

    final clearedOn =
        clearedOnMs ?? existing.chequeDate ?? existing.paymentDate;

    return write(() async {
      final response = await api.clearPayment(id, {
        'clearedDate': NepaliDate.toIsoDate(NepaliDate.fromMs(clearedOn)),
      });
      return SupplierPayment.fromJson(response.object);
    });
  }

  /// Cancelled, bounced or voided. It settled nothing, so the supplier's
  /// balance goes back up by this amount the next time it is read.
  Future<SupplierPayment?> markCancelled(String id) => write(() async {
        final response = await api.cancelPayment(id);
        return SupplierPayment.fromJson(response.object);
      });

  Future<void> delete(String id) => write(() => api.deletePayment(id));
}
