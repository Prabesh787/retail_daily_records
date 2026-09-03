import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nepali_date.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/fiscal_year_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// Recording one wholesale bill.
///
/// A purchase is the whole bill — supplier, number, date, amount. There are no
/// line items, because the shop does not track stock; that is a deliberate
/// limit of the system rather than a feature yet to be built.
class PurchaseFormController extends GetxController {
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();
  final FiscalYearRepository _years = Get.find<FiscalYearRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController billNo = TextEditingController();
  final TextEditingController amount = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController remarks = TextEditingController();
  final TextEditingController billDateBs = TextEditingController();

  final Rxn<Supplier> supplier = Rxn<Supplier>();
  final RxInt billDate = AppDateUtils.startOfTodayMs().obs;
  final RxnString supplierError = RxnString();
  final RxBool isSaving = false.obs;

  /// Set once the shopkeeper types in the BS field themselves. From then on the
  /// date picker stops overwriting it: the stored BS date is *what the bill
  /// says*, and a bill occasionally disagrees with the conversion — which is
  /// exactly the case worth preserving rather than silently correcting.
  bool _bsEdited = false;

  @override
  void onInit() {
    super.onInit();

    _syncBsFromDate();
    billDateBs.addListener(() {
      if (billDateBs.text != _derivedBs) _bsEdited = true;
    });

    // Opened from a supplier's page, so the party is already known.
    final args = Get.arguments;
    if (args is Map && args[RouteArgs.presetSupplierId] is String) {
      _preselect(args[RouteArgs.presetSupplierId] as String);
    }
  }

  String get _derivedBs => NepaliDate.msToBs(billDate.value) ?? '';

  void _syncBsFromDate() {
    if (_bsEdited) return;
    billDateBs.text = _derivedBs;
  }

  Future<void> _preselect(String supplierId) async {
    supplier.value = await _suppliers.byId(supplierId);
  }

  void setDate(int ms) {
    billDate.value = ms;
    _syncBsFromDate();
  }

  void setSupplier(Supplier value) {
    supplier.value = value;
    supplierError.value = null;
  }

  Future<List<Supplier>> searchSuppliers(String query) =>
      _suppliers.list(search: query.isEmpty ? null : query, includeInactive: false);

  Future<void> save() async {
    final formValid = formKey.currentState?.validate() ?? false;

    // The supplier is not a form field, so it validates separately — and both
    // checks run before returning, or picking a supplier would reveal a second
    // error that was there all along.
    if (supplier.value == null) {
      supplierError.value = 'Choose the supplier';
    }
    if (!formValid || supplier.value == null) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final year = await _years.forDate(billDate.value);
      if (year == null) {
        throw const ValidationException(
          'No fiscal year covers that date. Add one under More first.',
        );
      }

      final saved = await _purchases.save(
        Purchase(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: year.id,
          supplierId: supplier.value!.id,
          billNo: billNo.text.trim(),
          billDate: billDate.value,
          billDateBs: billDateBs.text.trim().isEmpty
              ? null
              : billDateBs.text.trim(),
          amount: Money.tryParse(amount.text) ?? Money.zero,
          description: _trimmed(description),
          remarks: _trimmed(remarks),
        ),
      );

      AppToast.success('Bill ${saved.billNo} recorded');
      // Replaces the form in the stack, so backing out of the bill you just
      // saved does not land on a filled-in form inviting a duplicate.
      Get.offNamed<void>(
        Routes.purchaseDetail,
        arguments: {RouteArgs.purchaseId: saved.id},
      );
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this bill. $e');
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
      billNo,
      amount,
      description,
      remarks,
      billDateBs,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
