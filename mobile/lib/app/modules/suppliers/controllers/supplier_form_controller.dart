import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// Creating or editing a supplier.
///
/// Master data, so unlike a bill this is editable in place — a phone number
/// changes, and re-issuing the supplier would split their balance in two.
class SupplierFormController extends GetxController {
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController contactPerson = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController pan = TextEditingController();
  final TextEditingController openingBalance = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  final RxBool isActive = true.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool canDelete = false.obs;

  String? _id;
  Supplier? _existing;

  bool get isEdit => _id != null;
  String get title => isEdit ? 'Edit supplier' : 'New supplier';

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is Map && args[RouteArgs.supplierId] is String) {
      _id = args[RouteArgs.supplierId] as String;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    isLoading.value = true;
    try {
      final supplier = await _suppliers.byId(_id!);
      if (supplier == null) {
        AppToast.error('That supplier no longer exists.');
        Get.back<void>();
        return;
      }

      _existing = supplier;
      name.text = supplier.name;
      contactPerson.text = supplier.contactPerson ?? '';
      phone.text = supplier.phone ?? '';
      email.text = supplier.email ?? '';
      address.text = supplier.address ?? '';
      pan.text = supplier.pan ?? '';
      remarks.text = supplier.remarks ?? '';
      isActive.value = supplier.isActive;
      openingBalance.text = supplier.openingBalance.isZero
          ? ''
          : supplier.openingBalance.toWire();

      // Deleting is offered only where it is actually allowed. A supplier with
      // documents against them cannot be removed — their bills would be
      // orphaned — so the button is absent rather than present and failing.
      canDelete.value = !await _suppliers.hasTransactions(_id!);
    } finally {
      isLoading.value = false;
    }
  }

  String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final draft = Supplier(
        // An empty id is what tells the repository this is new; on an edit the
        // rest of the existing row has to come along or fields the form does
        // not show would be wiped.
        id: _id ?? '',
        createdAt: _existing?.createdAt ?? 0,
        updatedAt: _existing?.updatedAt ?? 0,
        name: name.text.trim(),
        contactPerson: _trimmed(contactPerson),
        phone: _trimmed(phone),
        email: _trimmed(email),
        address: _trimmed(address),
        pan: _trimmed(pan),
        openingBalance:
            Money.tryParse(openingBalance.text) ?? Money.zero,
        isActive: isActive.value,
        remarks: _trimmed(remarks),
        // Sync status and device id are stamped by the repository — it is the
        // layer that knows the write is happening, so setting them here would
        // only be a guess it overwrites.
      );

      final saved = await _suppliers.save(draft);
      AppToast.success(isEdit ? 'Supplier updated' : '${saved.name} added');
      Get.back<Supplier>(result: saved);
    } on ValidationException catch (e) {
      // The duplicate-name rule lives in the repository, which is the only
      // place that can actually check it.
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this supplier. $e');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete() async {
    if (!isEdit) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${_existing?.name ?? 'supplier'}?',
      message: 'This removes them from the list. Records already entered '
          'against them are not affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _suppliers.delete(_id!);
      AppToast.success('Supplier deleted');
      Get.back<void>();
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    }
  }

  @override
  void onClose() {
    for (final field in [
      name,
      contactPerson,
      phone,
      email,
      address,
      pan,
      openingBalance,
      remarks,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
