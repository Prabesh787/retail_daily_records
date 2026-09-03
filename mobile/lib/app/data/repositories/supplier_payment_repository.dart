import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../models/supplier_payment.dart';
import '../enums/sync_status.dart';
import 'base_repository.dart';

class SupplierPaymentRepository extends BaseRepository {
  @override
  String get entity => DbTables.supplierPayment;

  Future<List<SupplierPayment>> list({
    String? supplierId,
    String? purchaseId,
    String? fiscalYearId,
    PaymentStatus? status,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) =>
      dbService.supplierPayments.all(
        supplierId: supplierId,
        purchaseId: purchaseId,
        fiscalYearId: fiscalYearId,
        status: status,
        fromMs: fromMs,
        toMs: toMs,
        search: search,
        limit: limit,
      );

  Future<SupplierPayment?> byId(String id) =>
      dbService.supplierPayments.byId(id);

  /// Cheques in the order the money has to be available — by the date written
  /// on them, not the day they were handed over.
  Future<List<SupplierPayment>> chequeRegister({
    bool onlyPending = true,
    int? fromMs,
    int? toMs,
  }) =>
      dbService.supplierPayments.chequeRegister(
        onlyPending: onlyPending,
        fromMs: fromMs,
        toMs: toMs,
      );

  Future<({Money total, int count})> uncleared() =>
      dbService.supplierPayments.uncleared();

  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) =>
      dbService.supplierPayments.totalBetween(fromMs, toMs);

  /// Records a payment to a supplier.
  ///
  /// A cheque defaults to `ISSUED` rather than `CLEARED`: handing one over is
  /// not the same as the bank debiting it, and that difference is the whole
  /// reason this app keeps a cheque register. Every other mode is money that
  /// has already moved.
  Future<SupplierPayment> save(SupplierPayment payment) async {
    if (payment.supplierId.isEmpty) {
      throw const ValidationException('A payment needs a supplier.');
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

    final isNew = payment.id.isEmpty;
    final voucherNo = payment.voucherNo?.trim();

    if (voucherNo != null && voucherNo.isNotEmpty) {
      if (await dbService.supplierPayments.voucherNoExists(
        fiscalYearId: payment.fiscalYearId,
        voucherNo: voucherNo,
        exceptId: isNew ? null : payment.id,
      )) {
        throw ValidationException('Voucher $voucherNo is already used this year.');
      }
    }

    final timestamp = nowMs;
    final status = isNew
        ? (payment.paymentMode.isCheque
            ? PaymentStatus.issued
            : PaymentStatus.cleared)
        : payment.status;

    final stamped = isNew
        ? SupplierPayment(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            fiscalYearId: payment.fiscalYearId,
            supplierId: payment.supplierId,
            purchaseId: payment.purchaseId,
            voucherNo: (voucherNo?.isEmpty ?? true) ? null : voucherNo,
            paymentDate: payment.paymentDate,
            paymentDateBs:
                payment.paymentDateBs ?? NepaliDate.msToBs(payment.paymentDate),
            paymentMode: payment.paymentMode,
            amount: payment.amount,
            chequeNo: payment.chequeNo?.trim(),
            // A cheque handed over with no date written on it is dated the day
            // it changed hands, which is what the register then plans around.
            chequeDate: payment.paymentMode.isCheque
                ? (payment.chequeDate ?? payment.paymentDate)
                : null,
            chequeDateBs: payment.chequeDateBs ??
                NepaliDate.msToBs(payment.chequeDate ?? payment.paymentDate),
            referenceNo: payment.referenceNo,
            // Cash is cleared the moment it changes hands, so it carries the
            // payment date; an issued cheque has cleared on no date at all.
            clearedDate:
                status == PaymentStatus.cleared ? payment.paymentDate : null,
            status: status,
            description: payment.description,
            remarks: payment.remarks,
            createdById: payment.createdById,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : payment.copyWith(
            paymentDateBs:
                payment.paymentDateBs ?? NepaliDate.msToBs(payment.paymentDate),
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await _persist(stamped, timestamp);
    return stamped;
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

    return _saveStatusChange(
      existing.copyWith(
        status: PaymentStatus.cleared,
        clearedDate: clearedOnMs ?? existing.chequeDate ?? existing.paymentDate,
      ),
    );
  }

  /// Cancelled, bounced or voided. It settled nothing, so the supplier's
  /// balance goes back up by this amount the next time it is read.
  Future<SupplierPayment?> markCancelled(String id) async {
    final existing = await byId(id);
    if (existing == null) return null;

    return _saveStatusChange(
      existing.copyWith(
        status: PaymentStatus.cancelled,
        clearClearedDate: true,
      ),
    );
  }

  /// Status changes skip [save]'s validation — the voucher number is already
  /// taken by this very row, and re-checking it would refuse the change.
  Future<SupplierPayment> _saveStatusChange(SupplierPayment payment) async {
    final timestamp = nowMs;
    final stamped = payment.copyWith(
      updatedAt: timestamp,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );
    await _persist(stamped, timestamp);
    return stamped;
  }

  Future<void> _persist(SupplierPayment payment, int timestamp) => write(
        (txn) async {
          await dbService.supplierPayments.upsert(txn, payment);
          await enqueue(
            txn,
            entity: DbTables.supplierPayment,
            entityId: payment.id,
            payload: payment.toJson(),
            updatedAt: timestamp,
          );
        },
      );

  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.supplierPayments.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.supplierPayment,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}
