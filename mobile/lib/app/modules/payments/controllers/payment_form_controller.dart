import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nepali_date.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/enums/supplier_payment_mode.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/fiscal_year_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// Paying a supplier.
///
/// The one screen where this product differs from a cash book: handing over a
/// cheque is recorded now, but the money has not left the bank. The form
/// captures that difference — a cheque gets its own number and its own date,
/// and the repository files it as ISSUED rather than CLEARED.
class PaymentFormController extends GetxController {
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amount = TextEditingController();
  final TextEditingController voucherNo = TextEditingController();
  final TextEditingController chequeNo = TextEditingController();
  final TextEditingController referenceNo = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController remarks = TextEditingController();
  final TextEditingController paymentDateBs = TextEditingController();

  final Rxn<Supplier> supplier = Rxn<Supplier>();
  final Rxn<Purchase> againstBill = Rxn<Purchase>();
  final Rx<SupplierPaymentMode> mode = SupplierPaymentMode.cash.obs;
  final RxInt paymentDate = AppDateUtils.startOfTodayMs().obs;
  final RxInt chequeDate = AppDateUtils.startOfTodayMs().obs;
  final RxnString supplierError = RxnString();
  final RxBool isSaving = false.obs;

  /// Set once the shopkeeper types in the BS field themselves, after which the
  /// date picker stops overwriting it — the same rule the bill form follows.
  bool _bsEdited = false;

  bool get isCheque => mode.value.isCheque;
  bool get hasReference => mode.value.hasReference;

  @override
  void onInit() {
    super.onInit();

    _syncBsFromDate();
    paymentDateBs.addListener(() {
      if (paymentDateBs.text != _derivedBs) _bsEdited = true;
    });

    final args = Get.arguments;
    if (args is! Map) return;

    // Opened from a supplier's page or from a bill. Arriving with the party
    // already chosen is the common case: nobody opens this form and then works
    // out who they are paying.
    final supplierId = args[RouteArgs.presetSupplierId];
    if (supplierId is String) _preselectSupplier(supplierId);

    final purchaseId = args[RouteArgs.presetPurchaseId];
    if (purchaseId is String) _preselectBill(purchaseId);
  }

  String get _derivedBs => NepaliDate.msToBs(paymentDate.value) ?? '';

  void _syncBsFromDate() {
    if (_bsEdited) return;
    paymentDateBs.text = _derivedBs;
  }

  Future<void> _preselectSupplier(String supplierId) async {
    supplier.value = await _suppliers.byId(supplierId);
  }

  Future<void> _preselectBill(String purchaseId) async {
    final bill = await _purchases.byId(purchaseId);
    againstBill.value = bill;

    // Paying one bill usually means paying what is left on it, so the amount
    // starts there rather than empty. It stays editable — part payments are
    // ordinary.
    final due = bill?.dueTotal;
    if (due != null && due.isPositive && amount.text.trim().isEmpty) {
      amount.text = due.toWire();
    }
  }

  void setDate(int ms) {
    paymentDate.value = ms;
    _syncBsFromDate();

    // A cheque dated before the day it was written is a typo far more often
    // than it is deliberate, so the cheque date follows the payment date up.
    if (chequeDate.value < ms) chequeDate.value = ms;
  }

  void setChequeDate(int ms) => chequeDate.value = ms;

  void setMode(SupplierPaymentMode value) => mode.value = value;

  void setSupplier(Supplier value) {
    supplier.value = value;
    supplierError.value = null;

    // The bill belongs to whoever it was raised against; changing the party
    // would leave a payment filed against another supplier's bill.
    if (againstBill.value?.supplierId != value.id) againstBill.value = null;
  }

  void setBill(Purchase? value) => againstBill.value = value;

  Future<List<Supplier>> searchSuppliers(String query) => _suppliers.list(
    search: query.isEmpty ? null : query,
    includeInactive: false,
  );

  /// Only this supplier's unpaid bills. A payment against a settled bill, or
  /// against someone else's, is not a choice worth offering.
  Future<List<Purchase>> searchBills(String query) async {
    final current = supplier.value;
    if (current == null) return const [];

    return _purchases.list(
      supplierId: current.id,
      onlyUnpaid: true,
      search: query.isEmpty ? null : query,
      limit: 50,
    );
  }

  Future<void> save() async {
    final formValid = formKey.currentState?.validate() ?? false;

    if (supplier.value == null) supplierError.value = 'Choose the supplier';
    if (!formValid || supplier.value == null) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final year = await _years.forDate(paymentDate.value);
      if (year == null) {
        throw const ValidationException(
          'No fiscal year covers that date. Add one under More first.',
        );
      }

      final saved = await _payments.save(
        SupplierPayment(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: year.id,
          supplierId: supplier.value!.id,
          purchaseId: againstBill.value?.id,
          voucherNo: _trimmed(voucherNo),
          paymentDate: paymentDate.value,
          paymentDateBs: _trimmed(paymentDateBs),
          paymentMode: mode.value,
          amount: Money.tryParse(amount.text) ?? Money.zero,
          // Cheque and reference fields are cleared unless the mode uses them,
          // so switching mode after typing cannot leave a stale cheque number
          // attached to a cash payment.
          chequeNo: isCheque ? _trimmed(chequeNo) : null,
          chequeDate: isCheque ? chequeDate.value : null,
          chequeDateBs: isCheque ? NepaliDate.msToBs(chequeDate.value) : null,
          referenceNo: hasReference ? _trimmed(referenceNo) : null,
          description: _trimmed(description),
          remarks: _trimmed(remarks),
        ),
      );

      AppToast.success(
        isCheque
            ? 'Cheque ${saved.chequeNo} recorded'
            : '${saved.amount.display()} paid',
      );
      Get.offNamed<void>(
        Routes.paymentDetail,
        arguments: {RouteArgs.paymentId: saved.id},
      );
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this payment. $e');
    } finally {
      isSaving.value = false;
    }
  }

  String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void onClose() {
    for (final field in [
      amount,
      voucherNo,
      chequeNo,
      referenceNo,
      description,
      remarks,
      paymentDateBs,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
