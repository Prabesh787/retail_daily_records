import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../routes/app_pages.dart';

/// Creating or editing a customer.
///
/// Doubles as the detail screen. A customer carries no derived balance — unlike
/// a supplier, whose whole page is arithmetic — so a separate read-only view
/// would show the same six fields with an edit button on top of them.
class CustomerFormController extends GetxController {
  final CustomerRepository _customers = Get.find<CustomerRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController pan = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool canDelete = false.obs;

  String? _id;
  Customer? _existing;

  bool get isEdit => _id != null;
  String get title => isEdit ? 'Edit customer' : 'New customer';

  Customer? get existing => _existing;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is Map && args[RouteArgs.customerId] is String) {
      _id = args[RouteArgs.customerId] as String;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    isLoading.value = true;
    try {
      final customer = await _customers.byId(_id!);
      if (customer == null) {
        AppToast.error('That customer no longer exists.');
        Get.back<void>();
        return;
      }

      _existing = customer;
      name.text = customer.name;
      phone.text = customer.phone ?? '';
      address.text = customer.address ?? '';
      pan.text = customer.pan ?? '';
      remarks.text = customer.remarks ?? '';

      // Offered only where it is allowed. A customer with invoices cannot be
      // removed — their sales would be orphaned — so the button is absent
      // rather than present and failing.
      canDelete.value = (customer.saleCount ?? 0) == 0;
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
      final saved = await _customers.save(
        Customer(
          id: _id ?? '',
          createdAt: _existing?.createdAt ?? 0,
          updatedAt: _existing?.updatedAt ?? 0,
          name: name.text.trim(),
          phone: _trimmed(phone),
          address: _trimmed(address),
          pan: _trimmed(pan),
          remarks: _trimmed(remarks),
        ),
      );

      AppToast.success(isEdit ? 'Customer updated' : '${saved.name} added');
      Get.back<Customer>(result: saved);
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this customer. $e');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete() async {
    if (!isEdit) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${_existing?.name ?? 'customer'}?',
      message: 'They will be removed from the list. Sales already recorded are '
          'not affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _customers.delete(_id!);
      AppToast.success('Customer deleted');
      Get.back<void>();
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    }
  }

  @override
  void onClose() {
    for (final field in [name, phone, address, pan, remarks]) {
      field.dispose();
    }
    super.onClose();
  }
}
