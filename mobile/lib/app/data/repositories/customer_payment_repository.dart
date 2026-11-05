import '../../core/constants/db_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../enums/sync_status.dart';
import '../models/customer_payment.dart';
import 'base_repository.dart';

/// Payment In. Follows the same rules as [SupplierPaymentRepository], facing the
/// other way.
class CustomerPaymentRepository extends BaseRepository {
  @override
  String get entity => DbTables.customerPayment;

  Future<List<CustomerPayment>> list({String? customerId, String? saleId}) =>
      dbService.customerPayments.all(customerId: customerId, saleId: saleId);

  Future<CustomerPayment?> byId(String id) =>
      dbService.customerPayments.byId(id);

  /// A cheque starts as ISSUED: having it in hand is not having the money.
  Future<CustomerPayment> save(CustomerPayment payment) async {
    if (payment.customerId.isEmpty) {
      throw const ValidationException('A payment needs a customer.');
    }
    if (payment.fiscalYearId.isEmpty) {
      throw const ValidationException(
        'There is no fiscal year to file this payment under.',
      );
    }
    if (!payment.amount.isPositive) {
      throw const ValidationException('A payment has to be more than zero.');
    }
    if (payment.paymentMode.isCheque &&
        (payment.chequeNo == null || payment.chequeNo!.trim().isEmpty)) {
      throw const ValidationException('A cheque payment needs its number.');
    }

    final voucherNo = payment.voucherNo?.trim();
    if (voucherNo != null && voucherNo.isNotEmpty) {
      if (await dbService.customerPayments.voucherNoExists(
        fiscalYearId: payment.fiscalYearId,
        voucherNo: voucherNo,
      )) {
        throw ValidationException('Receipt $voucherNo is already used this year.');
      }
    }

    final timestamp = nowMs;
    final isCheque = payment.paymentMode.isCheque;
    final status = isCheque ? PaymentStatus.issued : PaymentStatus.cleared;
    final chequeDate = isCheque
        ? (payment.chequeDate ?? payment.paymentDate)
        : null;

    final stamped = CustomerPayment(
      id: newId(),
      createdAt: timestamp,
      updatedAt: timestamp,
      fiscalYearId: payment.fiscalYearId,
      customerId: payment.customerId,
      saleId: payment.saleId,
      voucherNo: (voucherNo?.isEmpty ?? true) ? null : voucherNo,
      paymentDate: payment.paymentDate,
      paymentDateBs:
          payment.paymentDateBs ?? NepaliDate.msToBs(payment.paymentDate),
      paymentMode: payment.paymentMode,
      amount: payment.amount,
      accountId: payment.accountId,
      chequeNo: payment.chequeNo?.trim(),
      chequeDate: chequeDate,
      chequeDateBs: chequeDate == null ? null : NepaliDate.msToBs(chequeDate),
      referenceNo: payment.referenceNo,
      clearedDate: status == PaymentStatus.cleared ? payment.paymentDate : null,
      status: status,
      remarks: payment.remarks,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );

    await _persist(stamped, timestamp);
    return stamped;
  }

  /// The bank paid the cheque, and this is the moment the money reaches an
  /// account, which is why clearing has to say which one.
  Future<CustomerPayment?> markCleared(
    String id, {
    required String accountId,
    required int clearedOnMs,
  }) async {
    final existing = await byId(id);
    if (existing == null) return null;

    if (existing.status == PaymentStatus.cancelled) {
      throw const ValidationException(
        'A bounced cheque cannot be cleared. Record a new one.',
      );
    }

    return _statusChange(
      existing.copyWith(
        status: PaymentStatus.cleared,
        accountId: accountId,
        clearedDate: clearedOnMs,
      ),
    );
  }

  /// Bounced or entered by mistake. It settled nothing, so the amount goes back
  /// onto what the customer owes the next time that is read.
  Future<CustomerPayment?> markCancelled(String id) async {
    final existing = await byId(id);
    if (existing == null) return null;

    return _statusChange(
      existing.copyWith(
        status: PaymentStatus.cancelled,
        clearClearedDate: true,
      ),
    );
  }

  Future<CustomerPayment> _statusChange(CustomerPayment payment) async {
    final timestamp = nowMs;
    final stamped = payment.copyWith(
      updatedAt: timestamp,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );
    await _persist(stamped, timestamp);
    return stamped;
  }

  Future<void> _persist(CustomerPayment payment, int timestamp) => write(
    (txn) async {
      await dbService.customerPayments.upsert(txn, payment);
      await enqueue(
        txn,
        entity: DbTables.customerPayment,
        entityId: payment.id,
        payload: payment.toJson(),
        updatedAt: timestamp,
      );
    },
  );
}
